// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Pílula de período (gráficos): mesmo padrão visual no detalhe da startup e na carteira.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Chip em formato de pílula — fundo cinza, selecionado com lavado da cor primária.
class MesclaPeriodPillChip extends StatelessWidget {
  const MesclaPeriodPillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? primary.withValues(alpha: 0.12)
          : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? primary : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
