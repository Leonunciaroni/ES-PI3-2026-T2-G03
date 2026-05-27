// Eixo de datas com colunas iguais — evita sobreposição de rótulos no gráfico.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'chart_date_axis_ticks.dart';

/// Distribui [ticks] em colunas de largura igual (esquerda / centro / direita).
class ChartDateAxisLabels extends StatelessWidget {
  const ChartDateAxisLabels({
    super.key,
    required this.ticks,
    required this.theme,
  });

  final List<ChartDateAxisTick> ticks;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (ticks.isEmpty) return const SizedBox.shrink();

    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      color: AppColors.secondaryLabel(theme).withValues(alpha: 0.82),
    );

    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < ticks.length; i++)
            Expanded(
              child: Text(
                ticks[i].label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                textAlign: i == 0
                    ? TextAlign.left
                    : (i == ticks.length - 1
                          ? TextAlign.right
                          : TextAlign.center),
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}
