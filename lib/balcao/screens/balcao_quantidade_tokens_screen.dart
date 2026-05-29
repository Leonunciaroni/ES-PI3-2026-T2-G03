// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Compra e venda à mercado: o usuário informa **quantidade inteira de tokens**,
// confirma no diálogo e segue para a senha. Montantes em BRL alinham-se ao
// `EPSILON_BRL` ([balcao_format]).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../navigation/mescla_material_route.dart';
import '../../carteira/format/carteira_brl.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../theme/app_colors.dart';
import '../balcao_format.dart';
import '../balcao_official_price.dart';
import '../models/balcao_operacao_tipo.dart';
import 'balcao_compra_senha_screen.dart';

int? _parseQuantidadeTokensInteira(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  return int.tryParse(t);
}

bool _balcaoFirebaseProntoParaStreams() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

User? _balcaoAuthUserSeguro() {
  if (!_balcaoFirebaseProntoParaStreams()) return null;
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
}

/// Ecrã de quantidade de tokens (compra ou venda à mercado).
class BalcaoQuantidadeTokensScreen extends StatefulWidget {
  const BalcaoQuantidadeTokensScreen({
    super.key,
    required this.startup,
    required this.operacao,
    this.cotacaoOficialBrl,
  });

  final CatalogStartup startup;
  final BalcaoOperacaoTipo operacao;

  /// Último `tokenPriceBrl` da mesa ([getStartupMarketStats]); senão lê-se `preco_token` na validação.
  final double? cotacaoOficialBrl;

  @override
  State<BalcaoQuantidadeTokensScreen> createState() =>
      _BalcaoQuantidadeTokensScreenState();
}

class _BalcaoQuantidadeTokensScreenState
    extends State<BalcaoQuantidadeTokensScreen> {
  final _quantidadeController = TextEditingController(text: '2');

  String? _erroValidacao;

  BalcaoMercadoResolved? _resolvidoOperacaoMercado;

  @override
  void dispose() {
    _quantidadeController.dispose();
    super.dispose();
  }

  String get _tituloAppBar {
    switch (widget.operacao) {
      case BalcaoOperacaoTipo.compra:
        return 'Compra à mercado';
      case BalcaoOperacaoTipo.venda:
        return 'Venda à mercado';
    }
  }

  int? get _quantidadeParsed =>
      _parseQuantidadeTokensInteira(_quantidadeController.text);

  /// Pré-visualização síncrona: cotação vinda da mesa ou do catálogo.
  double get _precoUiPreview {
    final o = widget.cotacaoOficialBrl;
    if (o != null && o > 1e-9) return o;
    return widget.startup.tokenPrice;
  }

  BalcaoMercadoResolved? get _previewResolvido {
    final q = _quantidadeParsed;
    if (q == null || q <= 0) return null;
    final p = _precoUiPreview;
    if (!(p > 0)) return null;
    final r = balcaoResolveMercadoDesdeQuantidadeTokens(q, p);
    return r.isValid ? r : null;
  }

  Future<double?> _resolverPrecoMercadoNegocio(String fid) async {
    final o = widget.cotacaoOficialBrl;
    if (o != null && o > 1e-9) return o;
    final fromFs = await fetchPrecoTokenOficialBrl(fid);
    if (fromFs != null && fromFs > 1e-9) return fromFs;
    final c = widget.startup.tokenPrice;
    return c > 1e-9 ? c : null;
  }

  /// Tokens livres para venda (descontando escrow em ordens P2P abertas).
  Future<int> _consultarTokensDisponiveisVenda(String uid, String fid) async {
    final posSnap =
        await SimulatedWalletPaths.positionsCol(uid).doc(fid).get();
    if (!mounted) return 0;
    final posData = posSnap.data();
    final tokensHeld = posData?['tokensHeld'] is num
        ? (posData!['tokensHeld'] as num).toDouble()
        : 0.0;
    final tokensLocked = posData?['tokensLockedInOrders'] is int
        ? posData!['tokensLockedInOrders'] as int
        : posData?['tokensLockedInOrders'] is num
            ? (posData!['tokensLockedInOrders'] as num).toInt()
            : 0;
    return tokensHeld.floor() - tokensLocked;
  }

  /// BRL livre para compra (descontando escrow em ordens P2P abertas).
  Future<double> _consultarBrlDisponivelCompra(String uid) async {
    final walletSnap = await SimulatedWalletPaths.walletDoc(uid).get();
    if (!mounted) return 0;
    final walletData = walletSnap.data();
    final brlBalance = walletData?['brlBalance'] is num
        ? (walletData!['brlBalance'] as num).toDouble()
        : 0.0;
    final brlLocked = walletData?['brlLockedInOrders'] is num
        ? (walletData!['brlLockedInOrders'] as num).toDouble()
        : 0.0;
    return brlBalance - brlLocked;
  }

  Future<bool> _aplicarValidacaoCompleta() async {
    setState(() => _erroValidacao = null);
    _resolvidoOperacaoMercado = null;

    final user = _balcaoAuthUserSeguro();
    final fid = widget.startup.firestoreId?.trim();

    if (user == null) {
      setState(
        () => _erroValidacao = widget.operacao == BalcaoOperacaoTipo.compra
            ? 'Inicie sessão para usar o balcão com saldo fictício.'
            : 'Inicie sessão para vender tokens simulados.',
      );
      return false;
    }
    if (fid == null || fid.isEmpty) {
      setState(
        () => _erroValidacao =
            'Esta startup não está registada no catálogo Firebase (sem ID).',
      );
      return false;
    }

    final precoResolved = await _resolverPrecoMercadoNegocio(fid);
    if (!mounted) return false;
    if (precoResolved == null || !(precoResolved > 0)) {
      setState(
        () => _erroValidacao = widget.operacao == BalcaoOperacaoTipo.compra
            ? 'Cotação do token indisponível. Atualize a lista e volte ao Balcão.'
            : 'Cotação do token indisponível.',
      );
      return false;
    }

    final q = _quantidadeParsed;
    if (q == null) {
      setState(
        () => _erroValidacao =
            'Informe uma quantidade válida de tokens (número inteiro).',
      );
      return false;
    }
    if (q <= 0) {
      setState(
        () => _erroValidacao = 'A quantidade deve ser maior que zero.',
      );
      return false;
    }

    final r = balcaoResolveMercadoDesdeQuantidadeTokens(q, precoResolved);
    if (!r.isValid) {
      setState(
        () => _erroValidacao =
            'Quantidade e cotação não geram uma ordem válida. Ajuste a quantidade.',
      );
      return false;
    }

    switch (widget.operacao) {
      case BalcaoOperacaoTipo.compra:
        // Escrow P2P: só conta BRL não bloqueado em ordens abertas.
        final brlDisponivel = await _consultarBrlDisponivelCompra(user.uid);
        if (!mounted) return false;
        if (r.amountBrl > brlDisponivel + balcaoEpsilonBrl) {
          setState(
            () => _erroValidacao =
                'Disponível na carteira: ${formatBrl(brlDisponivel)}. '
                'O total à mercado (${formatBrl(r.amountBrl)}) excede esse saldo.',
          );
          return false;
        }
        break;
      case BalcaoOperacaoTipo.venda:
        final tokensDisponiveis =
            await _consultarTokensDisponiveisVenda(user.uid, fid);
        if (!mounted) return false;
        if (r.tokens > tokensDisponiveis) {
          setState(
            () => _erroValidacao =
                'Disponível para venda: até $tokensDisponiveis tokens.',
          );
          return false;
        }
        break;
    }

    _resolvidoOperacaoMercado = r;
    return true;
  }

  String _textoModalConfirmacao(BalcaoMercadoResolved resolvido) {
    final tokTxt = formatQuantidadeTokensBr(resolvido.tokens.toDouble());
    final totalTxt = formatBrl(resolvido.amountBrl);
    final unit = resolvido.tokens > 0
        ? resolvido.amountBrl / resolvido.tokens
        : _precoUiPreview;

    switch (widget.operacao) {
      case BalcaoOperacaoTipo.compra:
        return 'Confirmar compra à mercado de $tokTxt tokens por $totalTxt?\n'
            '(${formatBrl(unit)} / token).';
      case BalcaoOperacaoTipo.venda:
        return 'Confirmar venda à mercado de $tokTxt tokens por $totalTxt?';
    }
  }

  Future<void> _onContinuar() async {
    final aplicouOk = await _aplicarValidacaoCompleta();
    if (!mounted) return;

    final r = _resolvidoOperacaoMercado;

    if (!aplicouOk || r == null) return;

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
                  _textoModalConfirmacao(r),
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
        (context) => BalcaoCompraSenhaScreen(
          startup: widget.startup,
          operacao: widget.operacao,
          valorReaisOperacao: r.amountBrl,
          quantidadeTokensNegocio: r.tokens,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isVenda = widget.operacao == BalcaoOperacaoTipo.venda;
    final bodyBg = theme.brightness == Brightness.light
        ? AppColors.gradientBottom
        : AppColors.gradientBottomDark;
    final overlay = AppColors.shellOverlayStyle(theme.brightness);
    final onSurface = scheme.onSurface;
    final fid = widget.startup.firestoreId?.trim();
    final preview = _previewResolvido;

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
            _tituloAppBar,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.startup.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preço à mercado (referência): ${formatBrl(_precoUiPreview)} / token',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<User?>(
                stream: _balcaoFirebaseProntoParaStreams()
                    ? FirebaseAuth.instance.authStateChanges()
                    : Stream<User?>.value(null),
                builder: (context, authSnap) {
                  final u = authSnap.data;
                  if (u == null) {
                    return Text(
                      isVenda
                          ? 'Disponível para venda: faça login e use uma startup do catálogo Firebase.'
                          : 'Disponível para compras: faça login para ver o saldo BRL fictício.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                      ),
                    );
                  }
                  if (isVenda) {
                    if (fid == null || fid.isEmpty) {
                      return Text(
                        'Disponível para venda: faça login e use uma startup do catálogo Firebase.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      );
                    }
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: SimulatedWalletPaths.positionsCol(u.uid)
                          .doc(fid)
                          .snapshots(),
                      builder: (context, posSnap) {
                        final posData = posSnap.data?.data();
                        final tokensHeld = posData?['tokensHeld'] is num
                            ? (posData!['tokensHeld'] as num).toDouble()
                            : 0.0;
                        final tokensLocked = posData?['tokensLockedInOrders'] is int
                            ? posData!['tokensLockedInOrders'] as int
                            : posData?['tokensLockedInOrders'] is num
                                ? (posData!['tokensLockedInOrders'] as num)
                                    .toInt()
                                : 0;
                        final tokensDisponiveis =
                            tokensHeld.floor() - tokensLocked;
                        final p = _precoUiPreview;
                        final reaisFmt = !(p > 0)
                            ? '—'
                            : formatBrl(tokensDisponiveis * p);
                        return Text(
                          'Disponível para venda: $reaisFmt '
                          '($tokensDisponiveis tokens livres)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                          ),
                        );
                      },
                    );
                  }
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: SimulatedWalletPaths.walletDoc(u.uid).snapshots(),
                    builder: (context, walletSnap) {
                      final walletData = walletSnap.data?.data();
                      final brlBalance = walletData?['brlBalance'] is num
                          ? (walletData!['brlBalance'] as num).toDouble()
                          : 0.0;
                      final brlLocked = walletData?['brlLockedInOrders'] is num
                          ? (walletData!['brlLockedInOrders'] as num).toDouble()
                          : 0.0;
                      final brlDisponivel = brlBalance - brlLocked;
                      return Text(
                        'Disponível para compras: ${formatBrl(brlDisponivel)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                isVenda
                    ? 'Informe quantos tokens deseja vender à mercado (número inteiro).'
                    : 'Informe quantos tokens deseja comprar à mercado (número inteiro).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantidadeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  setState(() {
                    if (_erroValidacao != null) _erroValidacao = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Quantidade de tokens',
                  hintText: 'Ex.: 2 ou 10',
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
              if (_erroValidacao != null) ...[
                const SizedBox(height: 10),
                Text(
                  _erroValidacao!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                preview != null
                    ? 'Total estimado: ${formatBrl(preview.amountBrl)} · '
                        '${formatQuantidadeTokensBr(preview.tokens.toDouble())} tokens'
                    : 'Total estimado: —',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _onContinuar,
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
        ),
      ),
    );
  }
}
