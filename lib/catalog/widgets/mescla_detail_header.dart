// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Cabeçalho reutilizado nas telas de detalhe (startup, sócio, etc.):
// botão voltar + logo Mescla centrado, alinhado ao layout do Figma.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Altura visual do wordmark no eixo vertical (dp).
const double kMesclaDetailLogoHeight = 44;

/// Linha superior: [IconButton] de voltar, logo ao centro, espaçador à direita
/// para manter o logo geometricamente centrado na largura total.
class MesclaDetailHeader extends StatelessWidget {
  const MesclaDetailHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: theme.colorScheme.onSurface,
          tooltip: 'Voltar',
        ),
        Expanded(
          child: Center(
            child: Image.asset(
              AppColors.mesclaLogoAsset,
              height: kMesclaDetailLogoHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Text(
                'mescla invest',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        // Mesma largura aproximada do leading para não deslocar o logo.
        const SizedBox(width: 48),
      ],
    );
  }
}
