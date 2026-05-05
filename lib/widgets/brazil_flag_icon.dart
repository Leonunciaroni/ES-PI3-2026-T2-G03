import 'package:flutter/material.dart';

/// Bandeira do Brasil (PNG em assets) em formato circular — indica valores em BRL.
class BrazilFlagIcon extends StatelessWidget {
  const BrazilFlagIcon({
    super.key,
    this.diameter = 40,
  });

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Image.asset(
          'assets/images/brazil.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
