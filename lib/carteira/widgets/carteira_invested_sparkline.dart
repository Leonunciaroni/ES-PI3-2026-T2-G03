// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Mini gráfico em **linha** para o card “Minhas Startups Investidas”, coerente com
// o estilo dos gráficos de área (sem scrubbing — só leitura rápida).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Traço suave entre pontos normalizados no retângulo.
class CarteiraInvestedSparkline extends StatelessWidget {
  const CarteiraInvestedSparkline({
    super.key,
    required this.values,
    required this.color,
    this.width = 56,
    this.height = 32,
  });

  final List<double> values;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(width: width, height: height);
    }
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _CarteiraSparklinePainter(
          values: values,
          color: color,
        ),
      ),
    );
  }
}

class _CarteiraSparklinePainter extends CustomPainter {
  _CarteiraSparklinePainter({
    required this.values,
    required this.color,
  });

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 2) return;

    var vmin = values.reduce(math.min);
    var vmax = values.reduce(math.max);
    if (!vmin.isFinite || !vmax.isFinite) return;
    final span = (vmax - vmin).abs();
    if (span < 1e-9) {
      vmin -= 1;
      vmax += 1;
    }
    final pad = span * 0.15 + 0.5;
    var y0 = vmin - pad;
    final y1 = vmax + pad;
    final denom = (y1 - y0).abs() < 1e-12 ? 1.0 : (y1 - y0);

    final linePath = Path();
    for (var i = 0; i < n; i++) {
      final x = n <= 1 ? 0.0 : (i / (n - 1)) * size.width;
      final v = values[i];
      final t = ((v - y0) / denom).clamp(0.0, 1.0);
      final y = size.height - t * size.height;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final fillPath = Path()..addPath(linePath, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.15),
          Offset(0, size.height),
          [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.02),
          ],
        ),
    );

    final stroke = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawPath(linePath, stroke);
  }

  @override
  bool shouldRepaint(covariant _CarteiraSparklinePainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (values[i] != oldDelegate.values[i]) return true;
    }
    return false;
  }
}
