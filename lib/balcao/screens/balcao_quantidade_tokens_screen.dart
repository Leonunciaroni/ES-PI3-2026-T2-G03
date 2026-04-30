// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Compra: valor em reais a investir. Venda: o utilizador escolhe **em reais**
// ou **em tokens** (dois modos), depois confirma no diálogo e segue para a senha.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../navigation/mescla_material_route.dart';
import '../../carteira/format/carteira_brl.dart';
import '../../carteira/screens/adicionar_fundos_screen.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../theme/app_colors.dart';
import '../balcao_format.dart';
import '../models/balcao_operacao_tipo.dart';
import 'balcao_compra_senha_screen.dart';

/// Modo de entrada na **venda**: valor total em reais ou quantidade de tokens.
enum BalcaoVendaUnidade {
  reais,
  tokens,
}

/// Saldo em tokens na mesa (demo) — mesmo critério de [BalcaoTabScreen].
double _saldoTokensMesaMock(CatalogStartup s) {
  final h = s.name.hashCode.abs() % 1000;
  return 50 + h / 10.0;
}

double _saldoReaisMesaMock(CatalogStartup s) =>
    _saldoTokensMesaMock(s) * s.tokenPrice;

double _tokensParaValorReais(double valorReais, CatalogStartup s) {
  if (s.tokenPrice <= 0) return 0;
  return valorReais / s.tokenPrice;
}

double? _parseQuantidadeTokens(String raw) {
  final t = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Ecrã de valor (compra em R$; venda em R$ ou em tokens conforme escolha).
class BalcaoQuantidadeTokensScreen extends StatefulWidget {
  const BalcaoQuantidadeTokensScreen({
    super.key,
    required this.startup,
    required this.operacao,
  });

  final CatalogStartup startup;
  final BalcaoOperacaoTipo operacao;

  @override
  State<BalcaoQuantidadeTokensScreen> createState() =>
      _BalcaoQuantidadeTokensScreenState();
}

class _BalcaoQuantidadeTokensScreenState
    extends State<BalcaoQuantidadeTokensScreen> {
  final _valorReaisController = TextEditingController(text: '150,00');
  final _tokensVendaController = TextEditingController(text: '10');

  /// Só usado na venda: vender pelo valor em R$ ou pela quantidade de tokens.
  BalcaoVendaUnidade _vendaUnidade = BalcaoVendaUnidade.reais;

  String? _erroValidacao;

  @override
  void dispose() {
    _valorReaisController.dispose();
    _tokensVendaController.dispose();
    super.dispose();
  }

  String get _tituloAppBar {
    switch (widget.operacao) {
      case BalcaoOperacaoTipo.compra:
        return 'Valor do investimento';
      case BalcaoOperacaoTipo.venda:
        return 'Vender';
    }
  }

  double? get _valorReaisParsed =>
      parseValorReaisInput(_valorReaisController.text);

  double? get _quantidadeTokensVendaParsed =>
      _parseQuantidadeTokens(_tokensVendaController.text);

  double get _tokensEquivalentesCompra {
    final v = _valorReaisParsed;
    if (v == null || v <= 0) return 0;
    return _tokensParaValorReais(v, widget.startup);
  }

  double get _reaisEquivalentesVendaTokens {
    final q = _quantidadeTokensVendaParsed;
    if (q == null || q <= 0) return 0;
    return q * widget.startup.tokenPrice;
  }

  String _textoModalConfirmacao(double valorReaisOperacao) {
    switch (widget.operacao) {
      case BalcaoOperacaoTipo.compra:
        final tok = formatQuantidadeTokensBr(
          _tokensParaValorReais(valorReaisOperacao, widget.startup),
        );
        return 'Deseja confirmar o investimento de ${formatBrl(valorReaisOperacao)}?\nEquivale a $tok tokens.';
      case BalcaoOperacaoTipo.venda:
        if (_vendaUnidade == BalcaoVendaUnidade.reais) {
          final tok = formatQuantidadeTokensBr(
            _tokensParaValorReais(valorReaisOperacao, widget.startup),
          );
          return 'Deseja confirmar a venda no valor de ${formatBrl(valorReaisOperacao)}?\nEquivale a $tok tokens.';
        }
        final q = _quantidadeTokensVendaParsed!;
        return 'Deseja confirmar a venda de ${formatQuantidadeTokensBr(q)} tokens?\nEquivale a ${formatBrl(valorReaisOperacao)}.';
    }
  }

  Future<double> _resolverMaxTokensParaVenda() async {
    final u = FirebaseAuth.instance.currentUser;
    final fid = widget.startup.firestoreId;
    if (u == null || fid == null || fid.isEmpty) {
      return _saldoTokensMesaMock(widget.startup);
    }
    final t = await SimulatedWalletService.fetchTokensHeld(u.uid, fid);
    if (!mounted) {
      return _saldoTokensMesaMock(widget.startup);
    }
    return t ?? 0.0;
  }

  /// Devolve o valor da operação **sempre em reais** (para a tela de senha e detalhe).
  Future<double?> _validarEntrada() async {
    setState(() => _erroValidacao = null);

    switch (widget.operacao) {
      case BalcaoOperacaoTipo.compra:
        return _validarCompraFuturo();
      case BalcaoOperacaoTipo.venda:
        if (_vendaUnidade == BalcaoVendaUnidade.reais) {
          return _validarVendaReaisFuturo();
        }
        return _validarVendaTokensFuturo();
    }
  }

  Future<double?> _validarCompraFuturo() async {
    final v = _valorReaisParsed;
    if (v == null) {
      setState(() => _erroValidacao = 'Informe um valor válido em reais.');
      return null;
    }
    if (v <= 0) {
      setState(() => _erroValidacao = 'O valor deve ser maior que zero.');
      return null;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(
        () =>
            _erroValidacao = 'Inicie sessão para usar o balcão com saldo fictício.',
      );
      return null;
    }
    final fid = widget.startup.firestoreId;
    if (fid == null || fid.isEmpty) {
      setState(
        () => _erroValidacao =
            'Esta startup não está registada no catálogo Firebase (sem ID).',
      );
      return null;
    }
    final saldoDisponivel = await SimulatedWalletService.fetchBrlBalance(user.uid);
    if (!mounted) return null;
    if (v > saldoDisponivel + 1e-6) {
      setState(
        () => _erroValidacao =
            'Saldo disponível (${formatBrl(saldoDisponivel)}) insuficiente.',
      );
      return null;
    }
    return v;
  }

  Future<double?> _validarVendaReaisFuturo() async {
    final v = _valorReaisParsed;
    if (v == null) {
      setState(() => _erroValidacao = 'Informe um valor válido em reais.');
      return null;
    }
    if (v <= 0) {
      setState(() => _erroValidacao = 'O valor deve ser maior que zero.');
      return null;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final fid = widget.startup.firestoreId;
      if (fid == null || fid.isEmpty) {
        setState(
          () => _erroValidacao =
              'Esta startup não está registada no catálogo Firebase (sem ID).',
        );
        return null;
      }
    }
    final tokensNecessarios = _tokensParaValorReais(v, widget.startup);
    final maxT = await _resolverMaxTokensParaVenda();
    if (!mounted) return null;
    if (tokensNecessarios > maxT + 1e-9) {
      setState(
        () => _erroValidacao =
            'Disponível para venda: até ${formatQuantidadeTokensBr(maxT)} tokens.',
      );
      return null;
    }
    return v;
  }

  Future<double?> _validarVendaTokensFuturo() async {
    final q = _quantidadeTokensVendaParsed;
    if (q == null) {
      setState(() => _erroValidacao = 'Informe uma quantidade válida de tokens.');
      return null;
    }
    if (q <= 0) {
      setState(() => _erroValidacao = 'A quantidade deve ser maior que zero.');
      return null;
    }
    final userLogged = FirebaseAuth.instance.currentUser;
    if (userLogged != null) {
      final fid = widget.startup.firestoreId;
      if (fid == null || fid.isEmpty) {
        setState(
          () => _erroValidacao =
              'Esta startup não está registada no catálogo Firebase (sem ID).',
        );
        return null;
      }
    }
    final maxT = await _resolverMaxTokensParaVenda();
    if (!mounted) return null;
    if (q > maxT + 1e-12) {
      setState(
        () => _erroValidacao =
            'Disponível para venda: até ${formatQuantidadeTokensBr(maxT)} tokens.',
      );
      return null;
    }
    return q * widget.startup.tokenPrice;
  }

  Future<void> _onContinuar() async {
    final valor = await _validarEntrada();
    if (valor == null || !mounted) return;

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
                  _textoModalConfirmacao(valor),
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
          valorReaisOperacao: valor,
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
                'Preço unitário do token: ${formatBrl(widget.startup.tokenPrice)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
              if (isVenda) ...[
                const SizedBox(height: 4),
                Text(
                  'Disponível para venda: ${formatBrl(_saldoReaisMesaMock(widget.startup))} (${formatQuantidadeTokensBr(_saldoTokensMesaMock(widget.startup))} tokens)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
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
              ],
              const SizedBox(height: 16),
              if (!isVenda || _vendaUnidade == BalcaoVendaUnidade.reais) ...[
                Text(
                  isVenda
                      ? 'Informe o valor em reais da venda. Aceita vírgula ou ponto (ex.: 1.500,50).'
                      : 'Quanto deseja investir em reais? Aceita vírgula ou ponto (ex.: 1.500,50).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _valorReaisController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    setState(() {
                      if (_erroValidacao != null) _erroValidacao = null;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: isVenda
                        ? 'Valor em reais da venda'
                        : 'Quanto deseja investir (R\$)?',
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
                  'Informe quantos tokens deseja vender. Use vírgula ou ponto para decimais.',
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
                      ? 'Tokens equivalentes: ${formatQuantidadeTokensBr(_tokensEquivalentesCompra)}'
                      : 'Tokens equivalentes: —',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                )
              else if (_vendaUnidade == BalcaoVendaUnidade.reais)
                Text(
                  _valorReaisParsed != null && _valorReaisParsed! > 0
                      ? 'Tokens equivalentes: ${formatQuantidadeTokensBr(_tokensParaValorReais(_valorReaisParsed!, widget.startup))}'
                      : 'Tokens equivalentes: —',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                )
              else
                Text(
                  _quantidadeTokensVendaParsed != null &&
                          _quantidadeTokensVendaParsed! > 0
                      ? 'Valor em reais: ${formatBrl(_reaisEquivalentesVendaTokens)}'
                      : 'Valor em reais: —',
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
