import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cartão flutuante com data/hora em destaque + valor secundário (tooltips dos gráficos).
class MesclaChartReadingCard extends StatelessWidget {
  const MesclaChartReadingCard({
    super.key,
    required this.dateTimeLine,
    required this.valueLine,
    this.minWidth = 120,
  });

  final String dateTimeLine;
  final String valueLine;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateTimeLine,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valueLine,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
