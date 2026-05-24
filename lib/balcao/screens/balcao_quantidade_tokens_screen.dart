// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Compra: valor em reais a investir. Venda: o utilizador escolhe **em reais**
// ou **em tokens** (dois modos), depois confirma no diálogo e segue para a senha.
// Montantes enviados à Cloud Function são alinhados ao `EPSILON_BRL` ([balcao_format]).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../navigation/mescla_material_route.dart';
import '../../carteira/format/carteira_brl.dart';
import '../../carteira/format/carteira_valor_input.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../theme/app_colors.dart';
import '../balcao_format.dart';
import '../balcao_official_price.dart';
import '../models/balcao_operacao_tipo.dart';
import 'balcao_compra_senha_screen.dart';

/// Modo de entrada na **venda**: valor total em reais ou quantidade de tokens.
enum BalcaoVendaUnidade {
  reais,
  tokens,
}

double? _parseQuantidadeTokens(String raw) {
  final t = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
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

/// Ecrã de valor (compra em R$; venda em R$ ou em tokens conforme escolha).
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
  final _valorReaisController = TextEditingController();
  final _tokensVendaController = TextEditingController();

  /// Só usado na venda: vender pelo valor em R$ ou pela quantidade de tokens.
  BalcaoVendaUnidade _vendaUnidade = BalcaoVendaUnidade.reais;

  String? _erroValidacao;

  BalcaoMercadoResolved? _resolvidoOperacaoMercado;

  @override
  void dispose() {
    _valorReaisController.dispose();
    _tokensVendaController.dispose();
    super.dispose();
  }

  String get _tituloAppBar {
    switch (widget.operacao) {
      case BalcaoOperacaoTipo.compra:
        return 'Valor do investimento · mercado';
      case BalcaoOperacaoTipo.venda:
        return 'Venda à mercado';
    }
  }

  double? get _valorReaisParsed =>
      parseValorReaisInput(_valorReaisController.text);

  double? get _quantidadeTokensVendaParsed =>
      _parseQuantidadeTokens(_tokensVendaController.text);

  /// Pré-visualização síncrona: cotação vinda da mesa ou do catálogo.
  double get _precoUiPreview {
    final o = widget.cotacaoOficialBrl;
    if (o != null && o > 1e-9) return o;
    return widget.startup.tokenPrice;
  }

  double get _tokensEquivalentesCompra {
    final v = _valorReaisParsed;
    if (v == null || v <= 0) return 0;
    final p = _precoUiPreview;
    if (!(p > 0)) return 0;
    return balcaoResolveMercadoDesdeBrl(v, p).tokens;
  }

  double get _reaisEquivalentesVendaTokens {
    final q = _quantidadeTokensVendaParsed;
    if (q == null || q <= 0) return 0;
    final p = _precoUiPreview;
    if (!(p > 0)) return 0;
    return balcaoResolveMercadoDesdeQuantidadeTokens(q, p).amountBrl;
  }

  Future<double?> _resolverPrecoMercadoNegocio(String fid) async {
    final o = widget.cotacaoOficialBrl;
    if (o != null && o > 1e-9) return o;
    final fromFs = await fetchPrecoTokenOficialBrl(fid);
    if (fromFs != null && fromFs > 1e-9) return fromFs;
    final c = widget.startup.tokenPrice;
    return c > 1e-9 ? c : null;
  }

  Future<double> _consultarSaldoTokensPosicao() async {
    final u = _balcaoAuthUserSeguro();
    final fid = widget.startup.firestoreId?.trim();
    if (u == null || fid == null || fid.isEmpty) return 0;
    final t =
        await SimulatedWalletService.fetchTokensHeld(u.uid, fid);
    if (!mounted) return 0;
    return t ?? 0;
  }

  Future<bool> _aplicarValidacaoCompleta() async {
    setState(() => _erroValidacao = null);
    _resolvidoOperacaoMercado = null;

    final user = _balcaoAuthUserSeguro();
    final fid = widget.startup.firestoreId?.trim();

    switch (widget.operacao) {
      case BalcaoOperacaoTipo.compra:
        if (user == null) {
          setState(
            () => _erroValidacao =
                'Inicie sessão para usar o balcão com saldo fictício.',
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
            () => _erroValidacao =
                'Cotação do token indisponível. Atualize a lista e volte ao Balcão.',
          );
          return false;
        }
        final preco = precoResolved;
        final v = _valorReaisParsed;
        if (v == null) {
          setState(
            () => _erroValidacao =
                'Informe um valor válido em reais.',
          );
          return false;
        }
        if (v <= 0) {
          setState(
            () => _erroValidacao =
                'O valor deve ser maior que zero.',
          );
          return false;
        }
        final r = balcaoResolveMercadoDesdeBrl(v, preco);
        if (!r.isValid) {
          setState(
            () => _erroValidacao =
                'Valor e cotação não geram uma ordem válida. Ajuste o montante.',
          );
          return false;
        }

        final saldoDisponivel =
            await SimulatedWalletService.fetchBrlBalance(user.uid);
        if (!mounted) return false;
        if (r.amountBrl > saldoDisponivel + balcaoEpsilonBrl) {
          setState(
            () => _erroValidacao =
                'Disponível na carteira: ${formatBrl(saldoDisponivel)}. '
                'O total à mercado (${formatBrl(r.amountBrl)}) excede esse saldo.',
          );
          return false;
        }
        _resolvidoOperacaoMercado = r;
        return true;

      case BalcaoOperacaoTipo.venda:
        if (user == null) {
          setState(
            () => _erroValidacao =
                'Inicie sessão para vender tokens simulados.',
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
            () => _erroValidacao =
                'Cotação do token indisponível.',
          );
          return false;
        }
        final preco = precoResolved;

        late final BalcaoMercadoResolved rMercado;

        if (_vendaUnidade == BalcaoVendaUnidade.reais) {
          final v = _valorReaisParsed;
          if (v == null) {
            setState(
              () =>
                  _erroValidacao = 'Informe um valor válido em reais.',
            );
            return false;
          }
          if (v <= 0) {
            setState(
              () =>
                  _erroValidacao = 'O valor deve ser maior que zero.',
            );
            return false;
          }
          rMercado = balcaoResolveMercadoDesdeBrl(v, preco);
        } else {
          final q = _quantidadeTokensVendaParsed;
          if (q == null) {
            setState(
              () =>
                  _erroValidacao =
                      'Informe uma quantidade válida de tokens.',
            );
            return false;
          }
          if (q <= 0) {
            setState(
              () =>
                  _erroValidacao =
                      'A quantidade deve ser maior que zero.',
            );
            return false;
          }
          rMercado = balcaoResolveMercadoDesdeQuantidadeTokens(q, preco);
        }

        if (!rMercado.isValid) {
          setState(
            () =>
                _erroValidacao =
                    'Ordem não pôde ser calculada pela cotação atual.',
          );
          return false;
        }

        final maxT = await _consultarSaldoTokensPosicao();
        if (!mounted) return false;
        if (rMercado.tokens > maxT + 1e-9) {
          setState(
            () => _erroValidacao =
                'Disponível para venda: até ${formatQuantidadeTokensBr(maxT)} tokens.',
          );
          return false;
        }

        _resolvidoOperacaoMercado = rMercado;
        return true;
    }
  }

  String _textoModalConfirmacao(BalcaoMercadoResolved resolvido) {
    final tokTxt = formatQuantidadeTokensBr(resolvido.tokens);
    final totalTxt = formatBrl(resolvido.amountBrl);
    switch (widget.operacao) {
      case BalcaoOperacaoTipo.compra:
        final unit = resolvido.tokens > 1e-12
            ? resolvido.amountBrl / resolvido.tokens
            : _precoUiPreview;
        return 'Confirmar compra à mercado por um total de $totalTxt?\n'
            '$tokTxt tokens (${formatBrl(unit)} / token).';

      case BalcaoOperacaoTipo.venda:
        return _vendaUnidade == BalcaoVendaUnidade.tokens
            ? 'Confirmar venda à mercado de $tokTxt tokens por $totalTxt?'
            : 'Confirmar venda à mercado por $totalTxt?\n'
                'Equivale a $tokTxt tokens.';
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
              if (isVenda) ...[
                const SizedBox(height: 8),
                StreamBuilder<User?>(
                  stream: _balcaoFirebaseProntoParaStreams()
                      ? FirebaseAuth.instance.authStateChanges()
                      : Stream<User?>.value(null),
                  builder: (context, authSnap) {
                    final u = authSnap.data;
                    if (u == null ||
                        fid == null ||
                        fid.isEmpty) {
                      return Text(
                        'Disponível para venda: faça login e use uma startup do catálogo Firebase.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      );
                    }
                    return StreamBuilder<double>(
                      stream:
                          SimulatedWalletService.watchTokensHeld(
                        u.uid,
                        fid,
                      ),
                      builder: (context, posSnap) {
                        final t = posSnap.data ?? 0;
                        final p = _precoUiPreview;
                        final reaisFmt = !(p > 0)
                            ? '—'
                            : formatBrl(t * p);
                        return Text(
                          'Disponível para venda: $reaisFmt '
                          '(${formatQuantidadeTokensBr(t)} tokens na posição)',
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
                  'Como deseja vender?',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<BalcaoVendaUnidade>(
                  segments: const [
                    ButtonSegment<BalcaoVendaUnidade>(
                      value: BalcaoVendaUnidade.reais,
                      label: Text('Em reais'),
                      icon: Icon(Icons.payments_outlined, size: 18),
                    ),
                    ButtonSegment<BalcaoVendaUnidade>(
                      value: BalcaoVendaUnidade.tokens,
                      label: Text('Em tokens'),
                      icon: Icon(Icons.toll_outlined, size: 18),
                    ),
                  ],
                  selected: {_vendaUnidade},
                  onSelectionChanged: (Set<BalcaoVendaUnidade> next) {
                    setState(() {
                      _vendaUnidade = next.single;
                      _erroValidacao = null;
                    });
                  },
                ),
              ] else ...[
                const SizedBox(height: 8),
                StreamBuilder<User?>(
                  stream: _balcaoFirebaseProntoParaStreams()
                      ? FirebaseAuth.instance.authStateChanges()
                      : Stream<User?>.value(null),
                  builder: (context, authSnap) {
                    final u = authSnap.data;
                    if (u == null) {
                      return Text(
                        'Disponível para compras: faça login para ver o saldo BRL fictício.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      );
                    }
                    return StreamBuilder<double>(
                      stream: SimulatedWalletService.watchBrlBalance(u.uid),
                      builder: (context, snap) {
                        final b = snap.data ?? 0;
                        return Text(
                          'Disponível para compras: ${formatBrl(b)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              if (!isVenda || _vendaUnidade == BalcaoVendaUnidade.reais) ...[
                Text(
                  isVenda
                      ? 'Informe o total em reais da venda à mercado. Aceita vírgula ou ponto (ex.: 1.500,50).'
                      : 'Quanto deseja investir em reais à mercado? Aceita vírgula ou ponto (ex.: 1.500,50).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _valorReaisController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    CentavosParaReaisInputFormatter(),
                  ],
                  onChanged: (_) {
                    setState(() {
                      if (_erroValidacao != null) _erroValidacao = null;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: isVenda
                        ? 'Total em reais (venda)'
                        : 'Total em reais (compra)',
                    hintText: 'Ex.: 150 ou 1.500,50',
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
              ] else ...[
                Text(
                  'Informe quantos tokens deseja vender à mercado. Use vírgula ou ponto para decimais.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tokensVendaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    setState(() {
                      if (_erroValidacao != null) _erroValidacao = null;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Quantidade de tokens',
                    hintText: 'Ex.: 10 ou 2,5',
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
              ],
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
              if (!isVenda)
                Text(
                  _valorReaisParsed != null && _valorReaisParsed! > 0
                      ? 'Total estimado: ${formatBrl(balcaoResolveMercadoDesdeBrl(_valorReaisParsed!, _precoUiPreview).amountBrl)} · '
                          '${formatQuantidadeTokensBr(_tokensEquivalentesCompra)} tokens'
                      : 'Total estimado: —',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                )
              else if (_vendaUnidade == BalcaoVendaUnidade.reais)
                Text(
                  _valorReaisParsed != null && _valorReaisParsed! > 0
                      ? 'Total estimado: ${formatBrl(balcaoResolveMercadoDesdeBrl(_valorReaisParsed!, _precoUiPreview).amountBrl)} · '
                          '${formatQuantidadeTokensBr(balcaoResolveMercadoDesdeBrl(_valorReaisParsed!, _precoUiPreview).tokens)} tokens'
                      : 'Total estimado: —',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                )
              else
                Text(
                  _quantidadeTokensVendaParsed != null &&
                          _quantidadeTokensVendaParsed! > 0
                      ? 'Total estimado: ${formatBrl(_reaisEquivalentesVendaTokens)} · '
                          '${formatQuantidadeTokensBr(_quantidadeTokensVendaParsed!)} tokens'
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
