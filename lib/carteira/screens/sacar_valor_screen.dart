// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Primeiro passo do **fluxo de saque** (só visual): saldo disponível, valor em
// reais com máscara, escolha da chave PIX e modal de confirmação antes da senha.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../navigation/mescla_material_route.dart';
import '../../theme/app_colors.dart';
import '../format/carteira_brl.dart';
import '../format/carteira_valor_input.dart';
import '../models/pix_chave_ui.dart';
import '../services/simulated_wallet_service.dart';
import 'sacar_senha_screen.dart';

// --- Constantes locais ----------------------------------------------------------

/// Saldo fictício só para **convidado** (sem sessão), alinhado ao mock da Carteira.
const double _kSaldoBrlConvidadoDemo = 12450.0;

// --- Ecrã ---------------------------------------------------------------------

/// Formulário de saque: valor + chave; devolve as chaves atualizadas ao pai via [onChavesAlteradas].
class SacarValorScreen extends StatefulWidget {
  const SacarValorScreen({
    super.key,
    required this.chavesPixIniciais,
    required this.onChavesAlteradas,
    this.usarFirebaseParaSessao = true,
  });

  /// Cópia inicial vinda da [CarteiraScreen].
  final List<PixChaveUi> chavesPixIniciais;

  /// Sempre que a lista mudar (ex.: chave nova no diálogo), o pai pode persistir em memória.
  final ValueChanged<List<PixChaveUi>> onChavesAlteradas;

  /// Alinhado à [CarteiraScreen.usarFirebaseParaSessao] (testes no VM).
  final bool usarFirebaseParaSessao;

  @override
  State<SacarValorScreen> createState() => _SacarValorScreenState();
}

class _SacarValorScreenState extends State<SacarValorScreen> {
  final _valorController = TextEditingController();
  late List<PixChaveUi> _chaves;
  String? _chaveIdSelecionada;
  String? _erroValidacao;

  // --- Exibição do saldo (ícone de olho, como na Carteira) ----------------------

  /// Quando `true`, o montante em BRL não aparece na UI (privacidade).
  bool _ocultarSaldo = false;

  @override
  void initState() {
    super.initState();
    _chaves = List<PixChaveUi>.from(widget.chavesPixIniciais);
    if (_chaves.isNotEmpty) {
      _chaveIdSelecionada = _chaves.first.id;
    }
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  double? get _valorParsed => parseValorReaisInput(_valorController.text);

  PixChaveUi? get _chaveSelecionadaObj {
    final id = _chaveIdSelecionada;
    if (id == null) return null;
    for (final c in _chaves) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _notificarChavesAoPai() {
    widget.onChavesAlteradas(List<PixChaveUi>.from(_chaves));
  }

  String _saldoParaExibicao(double saldo) =>
      _ocultarSaldo ? 'R\$ ••••••' : formatBrl(saldo);

  void _alternarOcultarSaldo() {
    setState(() => _ocultarSaldo = !_ocultarSaldo);
  }

  // --- Diálogo: cadastrar chave rápida neste fluxo -----------------------------

  Future<void> _abrirDialogNovaChave() async {
    var tipo = 'E-mail';
    final valorCtrl = TextEditingController();
    final apelidoCtrl = TextEditingController();
    const tipos = ['E-mail', 'CPF', 'Telefone', 'Chave aleatória'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Nova chave PIX'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(tipo),
                      initialValue: tipo,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: [
                        for (final t in tipos)
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => tipo = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Chave',
                        hintText: 'E-mail, CPF, telefone ou EVP',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apelidoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Apelido (opcional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) {
      valorCtrl.dispose();
      apelidoCtrl.dispose();
      return;
    }

    final v = valorCtrl.text.trim();
    valorCtrl.dispose();
    final ap = apelidoCtrl.text.trim();
    apelidoCtrl.dispose();

    if (v.isEmpty) return;

    final novo = PixChaveUi(
      id: 'pix_${DateTime.now().millisecondsSinceEpoch}',
      tipoLabel: tipo,
      valor: v,
      apelido: ap.isEmpty ? null : ap,
    );

    setState(() {
      _chaves.add(novo);
      _chaveIdSelecionada = novo.id;
      _erroValidacao = null;
    });
    _notificarChavesAoPai();
  }

  // --- Modal de confirmação (mesmo espírito do Balcão) -------------------------

  Future<void> _onContinuar(double saldoDisponivel) async {
    setState(() => _erroValidacao = null);

    final valor = _valorParsed;
    if (valor == null || valor <= 0) {
      setState(() => _erroValidacao = 'Informe um valor válido em reais.');
      return;
    }

    if (valor > saldoDisponivel + 1e-9) {
      setState(() {
        _erroValidacao = _ocultarSaldo
            ? 'Valor acima do saldo disponível. Mostre o saldo (ícone do olho) para ver o limite.'
            : 'Valor acima do saldo disponível (${formatBrl(saldoDisponivel)}).';
      });
      return;
    }

    final chave = _chaveSelecionadaObj;
    if (chave == null) {
      setState(
        () => _erroValidacao =
            'Cadastre ou selecione uma chave PIX.',
      );
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Deseja confirmar o saque de ${formatBrl(valor)}?\n'
                  'Destino: ${chave.rotuloLista}.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: AppColors.secondaryLabel(theme),
                          side: BorderSide(color: AppColors.cardDivider(theme)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Confirmar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || confirmou != true) return;

    await Navigator.of(context).push<void>(
      MesclaMaterialRoute.fadeSlide<void>(
        (context) => SacarSenhaScreen(
          valorReais: valor,
          chavePix: chave,
        ),
      ),
    );
  }

  // --- UI principal -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final uid = widget.usarFirebaseParaSessao
        ? FirebaseAuth.instance.currentUser?.uid
        : null;
    final bodyBg = theme.brightness == Brightness.light
        ? AppColors.gradientBottom
        : AppColors.gradientBottomDark;
    final overlay = AppColors.shellOverlayStyle(theme.brightness);

    Widget corpoComSaldo(double saldo) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Saldo disponível para saque',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _saldoParaExibicao(saldo),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _alternarOcultarSaldo,
                  icon: Icon(
                    _ocultarSaldo
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.secondaryLabel(theme),
                  ),
                  tooltip: _ocultarSaldo
                      ? 'Mostrar saldo'
                      : 'Ocultar saldo',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Valor do saque (R\$)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryLabel(theme),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valorController,
              keyboardType: TextInputType.number,
              inputFormatters: [CentavosParaReaisInputFormatter()],
              onChanged: (_) {
                if (_erroValidacao != null) setState(() => _erroValidacao = null);
              },
              decoration: InputDecoration(
                labelText: 'Valor',
                hintText: '0,00',
                filled: true,
                fillColor: AppColors.searchFieldFillForTheme(theme),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.cardDivider(theme)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chave PIX de destino',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _abrirDialogNovaChave,
                  child: const Text('Nova chave'),
                ),
              ],
            ),
            if (_chaves.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Não há chaves cadastradas. Use “Nova chave” ou cadastre em '
                  '“Minhas Chaves PIX” na Carteira.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey<String>(_chaveIdSelecionada ?? ''),
                initialValue: _chaveIdSelecionada,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.searchFieldFillForTheme(theme),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardDivider(theme)),
                  ),
                ),
                items: [
                  for (final c in _chaves)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.rotuloLista,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) =>
                    setState(() => _chaveIdSelecionada = id),
              ),
            if (_erroValidacao != null) ...[
              const SizedBox(height: 12),
              Text(
                _erroValidacao!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _chaves.isEmpty
                  ? null
                  : () => _onContinuar(saldo),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bodyBg,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: onSurface,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: overlay,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Voltar',
          ),
          title: Text(
            'Sacar',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: uid == null
            ? corpoComSaldo(_kSaldoBrlConvidadoDemo)
            : StreamBuilder<double>(
                stream: SimulatedWalletService.watchBrlBalance(uid),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Saldo indisponível (${snap.error}).',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final saldo = snap.data ?? 0.0;
                  return corpoComSaldo(saldo);
                },
              ),
      ),
    );
  }
}
