// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Cartão branco com título em negrito — mesmo padrão visual das secções
// citadas no documento MesclaInvest §5.2 (sumário, estrutura societária, etc.).

import 'package:flutter/material.dart';

/// Raio dos cantos dos cards grandes nas telas de detalhe (Figma ~18–22 dp).
const double kMesclaDetailCardRadius = 22;

/// Secção genérica: fundo branco, sombra leve, [title] + [child].
class MesclaPdfSectionCard extends StatelessWidget {
  const MesclaPdfSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.elevation = 1,
  });

  final String title;
  final Widget child;

  /// O card principal da startup usa [elevation] 2; secções usam 1.
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kMesclaDetailCardRadius),
      elevation: elevation,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
