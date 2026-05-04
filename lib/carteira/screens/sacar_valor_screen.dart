// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Primeiro passo do **fluxo de saque**: saldo disponível, valor em reais com máscara,
// chave PIX e modal de confirmação antes da senha. Com sessão Firebase, as chaves
// vêm de `users/{uid}.chavesPix` ([UserFirestoreService.watchChavesPix]); convidado
// usa lista em memória e [onChavesAlteradas].

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/services/user_firestore_service.dart';
import '../../navigation/mescla_material_route.dart';
import '../../theme/app_colors.dart';
import '../format/carteira_brl.dart';
import '../format/carteira_valor_input.dart';
import '../format/pix_chave_input.dart';
import '../models/pix_chave_ui.dart';
import '../services/simulated_wallet_service.dart';
import 'sacar_senha_screen.dart';

// --- Constantes locais ----------------------------------------------------------

/// Saldo fictício só para **convidado** (sem sessão), alinhado ao mock da Carteira.
const double _kSaldoBrlConvidadoDemo = 12450.0;

// --- Ecrã ---------------------------------------------------------------------

/// Formulário de saque: valor + chave; com convidado, [onChavesAlteradas] atualiza a Carteira.
class SacarValorScreen extends StatefulWidget {
  const SacarValorScreen({
    super.key,
    required this.chavesPixIniciais,
    required this.onChavesAlteradas,
    this.usarFirebaseParaSessao = true,
  });

  /// Cópia inicial quando não há sessão Firestore para chaves.
  final List<PixChaveUi> chavesPixIniciais;

  /// Lista em RAM (convidado / testes) ou após alterações locais.
  final ValueChanged<List<PixChaveUi>> onChavesAlteradas;

  /// Alinhado à [CarteiraScreen.usarFirebaseParaSessao] (testes no VM).
  final bool usarFirebaseParaSessao;

  @override
  State<SacarValorScreen> createState() => _SacarValorScreenState();
}

class _SacarValorScreenState extends State<SacarValorScreen> {
  final _valorController = TextEditingController();

  /// Só usada quando [_modoChavesSoMemoria] é `true`.
  List<PixChaveUi> _chavesLocal = [];

  String? _chaveIdSelecionada;
  String? _erroValidacao;

  // --- Exibição do saldo (ícone de olho, como na Carteira) ----------------------

  /// Quando `true`, o montante em BRL não aparece na UI (privacidade).
  bool _ocultarSaldo = false;

  /// Convidado, teste VM, ou utilizador sem UID: chaves não vão ao Firestore.
  bool get _modoChavesSoMemoria =>
      !widget.usarFirebaseParaSessao ||
      FirebaseAuth.instance.currentUser == null;

  @override
  void initState() {
    super.initState();
    if (_modoChavesSoMemoria) {
      _chavesLocal = List<PixChaveUi>.from(widget.chavesPixIniciais);
      _sincronizarSelecao(_chavesLocal);
    }
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  void _sincronizarSelecao(List<PixChaveUi> chaves) {
    if (chaves.isEmpty) {
      _chaveIdSelecionada = null;
      return;
    }
    final id = _chaveIdSelecionada;
    if (id == null || !chaves.any((c) => c.id == id)) {
      _chaveIdSelecionada = chaves.first.id;
    }
  }

  double? get _valorParsed => parseValorReaisInput(_valorController.text);

  PixChaveUi? _chaveSelecionadaObj(List<PixChaveUi> chaves) {
    final id = _idDropdownValido(chaves) ?? _chaveIdSelecionada;
    if (id == null) return null;
    for (final c in chaves) {
      if (c.id == id) return c;
    }
    return null;
  }

  String? _idDropdownValido(List<PixChaveUi> chaves) {
    if (chaves.isEmpty) return null;
    final id = _chaveIdSelecionada;
    if (id != null && chaves.any((c) => c.id == id)) return id;
    return chaves.first.id;
  }

  String _saldoParaExibicao(double saldo) =>
      _ocultarSaldo ? 'R\$ ••••••' : formatBrl(saldo);

  void _alternarOcultarSaldo() {
    setState(() => _ocultarSaldo = !_ocultarSaldo);
  }

  // --- Diálogo: cadastrar chave rápida neste fluxo -----------------------------

  Future<void> _abrirDialogNovaChave({
    required List<PixChaveUi> atual,
    required bool modoMemoria,
  }) async {
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
                        if (v == null) return;
                        setLocal(() {
                          tipo = v;
                          valorCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    PixChaveValorTextField(
                      key: ValueKey<String>('valor_$tipo'),
                      tipoLabel: tipo,
                      controller: valorCtrl,
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
                  onPressed: () {
                    final err = mensagemErroValidacaoPixChave(
                      tipo,
                      valorCtrl.text,
                    );
                    if (err != null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(err)),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
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

    final v = pixValorParaPersistencia(tipo, valorCtrl.text);
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

    final next = List<PixChaveUi>.from(atual)..add(novo);

    try {
      if (modoMemoria) {
        setState(() {
          _chavesLocal = next;
          _chaveIdSelecionada = novo.id;
          _erroValidacao = null;
        });
        widget.onChavesAlteradas(List<PixChaveUi>.from(next));
      } else {
        await UserFirestoreService.saveChavesPix(next);
        if (!mounted) return;
        setState(() {
          _chaveIdSelecionada = novo.id;
          _erroValidacao = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível guardar a chave: $e')),
      );
    }
  }

  // --- Modal de confirmação (mesmo espírito do Balcão) -------------------------

  Future<void> _onContinuar(double saldoDisponivel, List<PixChaveUi> chaves) async {
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

    final chave = _chaveSelecionadaObj(chaves);
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
          debitarSaldoReal:
              widget.usarFirebaseParaSessao &&
              FirebaseAuth.instance.currentUser != null,
        ),
      ),
    );
  }

  // --- UI principal -----------------------------------------------------------

  Widget _corpoComSaldo({
    required ThemeData theme,
    required ColorScheme scheme,
    required double saldo,
    required List<PixChaveUi> chaves,
    required bool modoMemoria,
  }) {
    final idDropdown = _idDropdownValido(chaves);

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
                    const SizedBox(height: 4),
                    Text(
                      'Apenas saldo em reais (BRL); tokens não entram neste limite.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                        height: 1.3,
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
                onPressed: () => _abrirDialogNovaChave(
                  atual: chaves,
                  modoMemoria: modoMemoria,
                ),
                child: const Text('Nova chave'),
              ),
            ],
          ),
          if (chaves.isEmpty)
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
              key: ValueKey<String>(
                '${chaves.length}_${chaves.map((e) => e.id).join('|')}',
              ),
              initialValue: idDropdown,
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
                for (final c in chaves)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      c.rotuloLista,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => _chaveIdSelecionada = id),
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
            onPressed: chaves.isEmpty
                ? null
                : () => _onContinuar(saldo, chaves),
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

    Widget corpoSaldoEChaves(double saldo) {
      if (_modoChavesSoMemoria) {
        return _corpoComSaldo(
          theme: theme,
          scheme: scheme,
          saldo: saldo,
          chaves: _chavesLocal,
          modoMemoria: true,
        );
      }
      return StreamBuilder<List<PixChaveUi>>(
        stream: UserFirestoreService.watchChavesPix(),
        builder: (context, snapChaves) {
          if (snapChaves.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Chaves PIX indisponíveis (${snapChaves.error}).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final chaves = snapChaves.data ?? const <PixChaveUi>[];
          return _corpoComSaldo(
            theme: theme,
            scheme: scheme,
            saldo: saldo,
            chaves: chaves,
            modoMemoria: false,
          );
        },
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
            ? corpoSaldoEChaves(_kSaldoBrlConvidadoDemo)
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
                  return corpoSaldoEChaves(saldo);
                },
              ),
      ),
    );
  }
}
