// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Primeiro passo de **Adicionar fundos**: valor em reais (máscara centavos),
// confirmação em modal e navegação para o ecrã PIX.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../format/carteira_brl.dart';
import '../format/carteira_valor_input.dart';
import '../widgets/carteira_app_bar_logo.dart';
import 'pagamento_pix_screen.dart';

// --- Constantes deste fluxo ---------------------------------------------------

/// Preço de **1 token** em reais (mock até existir API) — usado só ao gerar o resumo no PIX.
const double kPrecoTokenReais = 15.30;

/// Ecrã para definir quanto investir em reais (fluxo alinhado ao wireframe / Figma).
class AdicionarFundosScreen extends StatefulWidget {
  const AdicionarFundosScreen({super.key});

  @override
  State<AdicionarFundosScreen> createState() => _AdicionarFundosScreenState();
}

class _AdicionarFundosScreenState extends State<AdicionarFundosScreen> {
  final _valorController = TextEditingController();

  static const _radiusCard = 20.0;
  static const _padH = 20.0;

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  double? get _valorReais => parseValorReaisInput(_valorController.text);

  /// Quantidade de tokens estimada (mock) para o ecrã seguinte.
  double? get _quantidadeTokens {
    final v = _valorReais;
    if (v == null || v <= 0) return null;
    return v / kPrecoTokenReais;
  }

  bool get _podeInvestir {
    final v = _valorReais;
    return v != null && v > 0;
  }

  /// [AlertDialog]: pergunta em duas linhas (valor em baixo), mesma hierarquia de botões.
  Future<void> _mostrarConfirmacao() async {
    final valor = _valorReais!;
    final tokens = _quantidadeTokens!;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final primary = theme.colorScheme.primary;
        // Largura confortável: um pouco menos que a faixa máxima anterior.
        final screenW = MediaQuery.sizeOf(dialogContext).width;
        final contentW = (screenW - 56).clamp(280.0, 500.0);

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
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
          content: SizedBox(
            width: contentW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mesma área de mensagem ~3 linhas (altura visual próxima do texto antigo).
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Confirma o investimento de',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: AppColors.secondaryLabel(theme),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${formatBrl(valor)}?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: AppColors.secondaryLabel(theme),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(
                      color: primary.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                    backgroundColor: theme.colorScheme.surface,
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
                    foregroundColor: theme.colorScheme.onPrimary,
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
    // Mesma lógica do shell: fundo claro suave no light; no escuro alinha ao gradiente.
    final bodyBg = theme.brightness == Brightness.light
        ? const Color(0xFFF3F4F6)
        : AppColors.gradientBottomDark;
    final overlay = AppColors.shellOverlayStyle(theme.brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bodyBg,
        appBar: AppBar(
          title: const CarteiraAppBarLogo(),
          centerTitle: true,
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: overlay,
          iconTheme: IconThemeData(color: onSurface),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Voltar',
          ),
          // Espelha a largura do [leading] para o título ficar centrado na barra.
          actions: const [SizedBox(width: 56, height: 56)],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(_padH, 4, _padH, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ADICIONAR SALDO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryLabel(theme),
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
                    color: AppColors.secondaryLabel(theme),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                // Cartão de superfície (não forçar branco no tema escuro).
                Material(
                  color: AppColors.themeCardSurface(theme),
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
                            color: AppColors.secondaryLabel(theme),
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
                                  CentavosParaReaisInputFormatter(),
                                ],
                                onChanged: (_) => setState(() {}),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0,00',
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintStyle: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: onSurface.withValues(
                                          alpha: 0.4,
                                        ),
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
                const SizedBox(height: 28),
                // CTA em “pílula” (sombra roxa suave como no layout).
                FilledButton(
                  onPressed: _podeInvestir ? _mostrarConfirmacao : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: _podeInvestir ? 4 : 0,
                    shadowColor: AppColors.primaryShadow(theme.colorScheme),
                    shape: const StadiumBorder(),
                    backgroundColor: primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    disabledBackgroundColor: theme.brightness == Brightness.dark
                        ? theme.colorScheme.surfaceContainerHigh
                        : theme.colorScheme.surfaceContainerHighest,
                    disabledForegroundColor: theme.colorScheme.onSurface
                        .withValues(alpha: 0.38),
                  ),
                  child: const Text(
                    'Investir agora',
                    style: TextStyle(
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
    );
  }
}
