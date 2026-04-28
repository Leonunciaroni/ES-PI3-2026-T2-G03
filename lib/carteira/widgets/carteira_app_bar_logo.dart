// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Logo Mescla centrado na [AppBar] (ecrãs fundos / PIX).

import 'package:flutter/material.dart';

import '../../theme/mescla_brand_logo.dart';

/// Logo da marca, centrado no espaço do título da [AppBar].
class CarteiraAppBarLogo extends StatelessWidget {
  const CarteiraAppBarLogo({super.key});

  static const _logoHeight = 48.0;
  static const _logoBoxWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: MesclaBrandLogo(
        boxWidth: _logoBoxWidth,
        boxHeight: _logoHeight,
      ),
    );
  }
}
