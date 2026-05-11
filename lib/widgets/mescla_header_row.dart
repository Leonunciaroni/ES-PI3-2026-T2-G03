import 'package:flutter/material.dart';

import '../theme/mescla_brand_logo.dart';

/// Cabeçalho padrão do app (abas do shell): wordmark à esquerda e ação opcional à direita.
class MesclaHeaderRow extends StatelessWidget {
  const MesclaHeaderRow({
    super.key,
    this.trailing,
    this.logoBoxWidth = 200,
    this.logoBoxHeight = 52,
  });

  final Widget? trailing;
  final double logoBoxWidth;
  final double logoBoxHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MesclaBrandLogo(
          boxWidth: logoBoxWidth,
          boxHeight: logoBoxHeight,
        ),
        const Spacer(),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

