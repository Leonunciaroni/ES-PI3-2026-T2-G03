// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Cartão da lista **Minhas startups investidas** na Carteira e no Dashboard.
// Mostra nome, setor (caps), avatar (Storage/URL ou cor+ícone), rendimento %
// já formatado pelo pai e mini sparkline igual à Carteira para manter UX única.

import 'package:flutter/material.dart';

import '../../catalog/widgets/startup_logo_avatar.dart';
import '../../theme/app_colors.dart';
import '../invested_startup_position_math.dart';
import 'carteira_invested_sparkline.dart';

/// Dados vindos da posição (`sim_wallet/.../positions`) + opcionalmente do catálogo.
/// Mantém apenas o necessário ao layout visual do cartão — demais valores (custos etc.)
/// são tratados no ecrã que monta a lista (`CarteiraScreen`, `DashboardScreen`).
class InvestedStartupRowUi {
  const InvestedStartupRowUi({
    required this.nome,
    required this.categoria,
    required this.corLogo,
    required this.icone,
    this.logoPath,
  });

  final String nome;
  final String categoria;
  final Color corLogo;
  final IconData icone;

  /// `null` = só ícone sobre [corLogo] (fallback igual ao Catálogo).
  final String? logoPath;
}

/// Roxo / verde / vermelho acima da percentagem conforme ganho/perda (mesma política Carteira).
Color investedCardCorRendimento({
  required CarteiraInvestidoYieldTone tone,
  required Color schemePrimary,
}) {
  switch (tone) {
    case CarteiraInvestidoYieldTone.positivo:
      return const Color(0xFF16A34A);
    case CarteiraInvestidoYieldTone.negativo:
      return const Color(0xFFDC2626);
    case CarteiraInvestidoYieldTone.neutro:
    case CarteiraInvestidoYieldTone.indefinido:
      return schemePrimary;
  }
}

/// Cor do montante "Valor atual" (neutro = mesma tinta da superfície onSurface).
Color investedCardCorValorAtualMontante({
  required ThemeData theme,
  required CarteiraInvestidoYieldTone tone,
}) {
  switch (tone) {
    case CarteiraInvestidoYieldTone.positivo:
      return const Color(0xFF16A34A);
    case CarteiraInvestidoYieldTone.negativo:
      return const Color(0xFFDC2626);
    case CarteiraInvestidoYieldTone.neutro:
      return theme.colorScheme.onSurface;
    case CarteiraInvestidoYieldTone.indefinido:
      return AppColors.secondaryLabel(theme);
  }
}

/// Cor do mini gráfico: verde ↑, vermelho ↓; roxo se ~0 ou sem série.
Color investedCardCorSparkline({
  required Color schemePrimary,
  required CarteiraInvestidoYieldTone tone,
}) {
  switch (tone) {
    case CarteiraInvestidoYieldTone.positivo:
      return const Color(0xFF16A34A);
    case CarteiraInvestidoYieldTone.negativo:
      return const Color(0xFFDC2626);
    case CarteiraInvestidoYieldTone.neutro:
    case CarteiraInvestidoYieldTone.indefinido:
      return schemePrimary;
  }
}

/// Cartão igual ao utilizado na [CarteiraScreen] antes da extração.
class InvestedStartupCard extends StatelessWidget {
  const InvestedStartupCard({
    super.key,
    required this.startup,
    required this.primary,
    required this.hideValues,
    required this.rendimentoExibicao,
    required this.investidoExibicao,
    required this.valorAtualExibicao,
    required this.sparklineValues,
    required this.rendimentoTone,
  });

  /// Metadados e branding visuais (nome, ícone/logo).
  final InvestedStartupRowUi startup;

  /// Cor primária do tema (estado neutro nos percentuais).
  final Color primary;

  /// `true`: esconder números sensíveis e o sparkline como em resto das telas.
  final bool hideValues;

  /// Texto já passado pelo pai (pode incluir mascaração `•••`).
  final String rendimentoExibicao;
  final String investidoExibicao;

  /// Valor atual de mercado; `—` se indeterminável.
  final String valorAtualExibicao;

  /// Séries já calculadas pela matemática de posição [`carteiraSingleStartupSparklineValues`].
  final List<double> sparklineValues;

  /// Derivado dos custos/préços — governa apenas cor.
  final CarteiraInvestidoYieldTone rendimentoTone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corRend = investedCardCorRendimento(
      tone: rendimentoTone,
      schemePrimary: primary,
    );
    final corValorAtual = investedCardCorValorAtualMontante(
      theme: theme,
      tone: rendimentoTone,
    );
    final corSpark = investedCardCorSparkline(
      schemePrimary: primary,
      tone: rendimentoTone,
    );
    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StartupLogoAvatar(
                  logoPath: startup.logoPath,
                  fallbackColor: startup.corLogo,
                  fallbackIcon: startup.icone,
                  size: 48,
                  borderRadius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        startup.nome,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        startup.categoria,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rendimentoExibicao,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: corRend,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RENDIMENTO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: corRend,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total investido',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        investidoExibicao,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor atual',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        valorAtualExibicao,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: corValorAtual,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!hideValues)
                  CarteiraInvestedSparkline(
                    values: sparklineValues,
                    color: corSpark,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
