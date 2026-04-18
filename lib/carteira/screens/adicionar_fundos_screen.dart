// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Primeiro passo de **Adicionar fundos**: valor em reais, conversão para tokens,
// cotação com validade de [kCotacaoSegundos], confirmação e navegação para PIX.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../format/carteira_brl.dart';
import '../widgets/carteira_app_bar_logo.dart';
import 'pagamento_pix_screen.dart';

/// Formata o campo enquanto digita: só **dígitos**; os dois últimos são centavos
/// (ex.: `100000` → `1.000,00`). O [parseValorReaisInput] continua a aceitar texto já formatado.
class _CentavosParaReaisInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    if (digits.length > 14) {
      return oldValue;
    }
    final centavos = int.tryParse(digits);
    if (centavos == null) {
      return oldValue;
    }
    final reais = centavos / 100.0;
    final texto = formatBrlCampo(reais);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Duração da cotação do token em segundos (regra de negócio de demo).
const int kCotacaoSegundos = 20;

/// Preço de **1 token** em reais (mock até existir API).
const double kPrecoTokenReais = 15.30;

/// Interpreta o texto do campo como valor em reais.
///
/// Formatos aceites (PI, simples):
/// - `1000` ou `1.000` (pontos como milhar, sem centavos)
/// - `1000,50` ou `1.000,50` (vírgula como separador decimal à brasileira)
/// - `1000.50` (um ponto só, tratado como decimal estilo US)
double? parseValorReaisInput(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'R\$', caseSensitive: true), '');
  s = s.replaceAll(' ', '');
  if (s.isEmpty) return null;

  if (s.contains(',')) {
    final last = s.lastIndexOf(',');
    final intPart = s.substring(0, last).replaceAll(RegExp(r'[^\d]'), '');
    var dec = s.substring(last + 1).replaceAll(RegExp(r'[^\d]'), '');
    if (dec.length > 2) dec = dec.substring(0, 2);
    if (intPart.isEmpty && dec.isEmpty) return null;
    return double.tryParse(
      '${intPart.isEmpty ? '0' : intPart}.${dec.isEmpty ? '00' : dec.padRight(2, '0')}',
    );
  }

  final limpo = s.replaceAll(RegExp(r'[^\d.]'), '');
  if (limpo.isEmpty) return null;
  final pontos = '.'.allMatches(limpo).length;
  if (pontos == 1 && RegExp(r'^\d+\.\d{1,2}$').hasMatch(limpo)) {
    return double.tryParse(limpo);
  }
  return double.tryParse(limpo.replaceAll('.', ''));
}

/// Ecrã para definir quanto investir em reais e ver a conversão em tokens.
class AdicionarFundosScreen extends StatefulWidget {
  const AdicionarFundosScreen({super.key});

  @override
  State<AdicionarFundosScreen> createState() => _AdicionarFundosScreenState();
}

class _AdicionarFundosScreenState extends State<AdicionarFundosScreen> {
  final _valorController = TextEditingController();
  Timer? _timerCotacao;
  int _segundosCotacao = kCotacaoSegundos;

  static const _radiusCard = 20.0;
  static const _padH = 20.0;

  @override
  void initState() {
    super.initState();
    _iniciarOuReiniciarTimerCotacao();
  }

  void _iniciarOuReiniciarTimerCotacao() {
    _timerCotacao?.cancel();
    setState(() => _segundosCotacao = kCotacaoSegundos);
    _timerCotacao = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_segundosCotacao <= 0) {
        _timerCotacao?.cancel();
        setState(() {});
        return;
      }
      setState(() => _segundosCotacao--);
    });
  }

  @override
  void dispose() {
    _timerCotacao?.cancel();
    _valorController.dispose();
    super.dispose();
  }

  double? get _valorReais => parseValorReaisInput(_valorController.text);

  double? get _quantidadeTokens {
    final v = _valorReais;
    if (v == null || v <= 0) return null;
    return v / kPrecoTokenReais;
  }

  bool get _podeInvestir {
    final v = _valorReais;
    return v != null && v > 0 && _segundosCotacao > 0;
  }

  String _contagemMmSs(int s) {
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _mostrarConfirmacao() async {
    final valor = _valorReais!;
    final tokens = _quantidadeTokens!;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final primary = theme.colorScheme.primary;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(
            Icons.shield_outlined,
            size: 40,
            color: primary.withValues(alpha: 0.9),
          ),
          title: Text(
            'Confirmar transação',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirma o investimento de ${formatBrl(valor)} '
                '(${tokens.toStringAsFixed(2).replaceAll('.', ',')} tokens) '
                'com base na cotação atual?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.65), width: 1.5),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Cancelar'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => PagamentoPixScreen(
                        valorReais: valor,
                        quantidadeTokens: tokens,
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: AppColors.primaryShadow(theme.colorScheme),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    const appBarFg = Colors.black;
    final tokens = _quantidadeTokens;
    final cotacaoAtiva = _segundosCotacao > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.systemUiLightAppBar,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const CarteiraAppBarLogo(),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: appBarFg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: AppColors.systemUiLightAppBar,
          iconTheme: const IconThemeData(color: appBarFg),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Voltar',
          ),
          // Espelha a largura do [leading] para o título ficar centrado na barra.
          actions: const [
            SizedBox(width: 56, height: 56),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.gradientTop,
                AppColors.gradientBottom,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(_padH, 4, _padH, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ADICIONAR SALDO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quanto deseja investir?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Digite só números: os dois últimos dígitos são centavos '
                    '(ex.: 100000 → 1.000,00). A formatação atualiza ao digitar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(_radiusCard),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Valor em reais',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                color: primary.withValues(alpha: 0.75),
                                size: 26,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'R\$',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: primary,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _valorController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    _CentavosParaReaisInputFormatter(),
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0,00',
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintStyle: theme.textTheme.headlineSmall?.copyWith(
                                      color: AppColors.textSecondary.withValues(alpha: 0.45),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: primary.withValues(alpha: 0.06),
                    elevation: 0,
                    borderRadius: BorderRadius.circular(_radiusCard),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.currency_exchange_rounded,
                                size: 22,
                                color: primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Resumo da cotação',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '1 token =',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                formatBrl(kPrecoTokenReais),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                ),
                              ),
                            ],
                          ),
                          Divider(
                            height: 28,
                            color: AppColors.fieldBorder,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Você recebe',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (tokens != null && (_valorReais ?? 0) > 0)
                                Text(
                                  '${tokens.toStringAsFixed(2).replaceAll('.', ',')} tokens',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: primary,
                                  ),
                                )
                              else
                                Text(
                                  '—',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Material(
                    color: Colors.white,
                    elevation: 1,
                    shadowColor: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(_radiusCard),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cotacaoAtiva
                                  ? primary.withValues(alpha: 0.12)
                                  : AppColors.fieldBorder.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.timer_outlined,
                              color: cotacaoAtiva ? primary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cotacaoAtiva
                                      ? 'Cotação válida'
                                      : 'Cotação expirada',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cotacaoAtiva
                                      ? 'Tempo restante ${_contagemMmSs(_segundosCotacao)}. Renove após o fim do tempo.'
                                      : 'Toque em “Renovar cotação” para obter novos 20 segundos.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (cotacaoAtiva)
                            Text(
                              _contagemMmSs(_segundosCotacao),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!cotacaoAtiva)
                    OutlinedButton.icon(
                      onPressed: _iniciarOuReiniciarTimerCotacao,
                      icon: const Icon(Icons.refresh_rounded, size: 22),
                      label: const Text('Renovar cotação (20 s)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  if (!cotacaoAtiva) const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _podeInvestir ? _mostrarConfirmacao : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: _podeInvestir ? 3 : 0,
                      shadowColor: AppColors.primaryShadow(theme.colorScheme),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      cotacaoAtiva
                          ? 'Investir agora'
                          : 'Investir (cotação indisponível)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
