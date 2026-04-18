// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Logo Mescla centrado na [AppBar] (ecrãs fundos / PIX).

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Logo da marca, centrado no espaço do título da [AppBar].
class CarteiraAppBarLogo extends StatelessWidget {
  const CarteiraAppBarLogo({super.key});

  static const _logoHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Image.asset(
        AppColors.mesclaLogoAsset,
        height: _logoHeight,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
