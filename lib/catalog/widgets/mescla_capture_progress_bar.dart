// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Barra de progresso de captação reutilizada no **catálogo** e no **detalhe** da startup,
// para o mesmo aspeto visual (cantos redondos, altura, acessibilidade).

import 'package:flutter/material.dart';

/// Barra linear determinística [0, 1] com cantos totalmente redondos.
///
/// [value] é a fração já atingida (ex.: 0.35 = 35%). Nunca passa valores > 1 ao
/// [LinearProgressIndicator] — usamos [clamp] antes de desenhar.
class MesclaCaptureProgressBar extends StatelessWidget {
  const MesclaCaptureProgressBar({
    super.key,
    required this.value,
    required this.trackColor,
    required this.fillColor,
    this.height = 10,
    this.semanticsLabel,
  });

  /// Fração 0.0–1.0 da meta de captação.
  final double value;

  /// Cor do fundo (trilho vazio).
  final Color trackColor;

  /// Cor do preenchimento.
  final Color fillColor;

  /// Espessura da barra (altura).
  final double height;

  /// Texto para leitores de tela; se null, gera um rótulo com o percentual arredondado.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final double clamped = value.clamp(0.0, 1.0);
    final int pct = (clamped * 100).round();
    final String label =
        semanticsLabel ?? 'Progresso da captação: $pct por cento da meta';

    return Semantics(
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: clamped,
          minHeight: height,
          backgroundColor: trackColor,
          color: fillColor,
        ),
      ),
    );
  }
}
