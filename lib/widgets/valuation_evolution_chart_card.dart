// Gráfico de área (mesma interação que o detalhe da startup) + chips de período.
// Partilhado entre [StartupDetailScreen] e o Balcão (cotação do token em BRL).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../catalog/data/startup_detail_mock.dart';
import '../theme/app_colors.dart';
import 'chart_scrubbing.dart';
import 'mescla_chart_reading_card.dart';

/// Raio de canto alinhado ao detalhe da startup (~22 dp).
const double kValuationChartCardRadius = 22.0;

const _monthLabelsPt = <String>[
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String _defaultYAxisMillion(double millions) {
  if (millions >= 1000) {
    return 'R\$ ${(millions / 1000).toStringAsFixed(1)}B';
  }
  if (millions >= 100) {
    return 'R\$ ${millions.round()}M';
  }
  return 'R\$ ${millions.toStringAsFixed(1)}M';
}

String _defaultTooltipMillion(double millions) {
  if (millions >= 1000) {
    return 'R\$ ${(millions / 1000).toStringAsFixed(2)} bi';
  }
  return 'R\$ ${millions.toStringAsFixed(2)} mi';
}

String _diaMes(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

String _mesCurto(DateTime date) => _monthLabelsPt[date.month - 1];

DateTime _inicioDia(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _proximaSegunda(DateTime date) {
  final base = _inicioDia(date);
  final diasAteSegunda = (DateTime.monday - base.weekday) % 7;
  return base.add(Duration(days: diasAteSegunda));
}

class _DateAxisTick {
  const _DateAxisTick({required this.t, required this.label});

  final double t;
  final String label;
}

List<_DateAxisTick> _dateAxisTicks({
  required ValuationPeriod period,
  required List<DateTime> times,
}) {
  if (period == ValuationPeriod.diario || times.length < 2) {
    return const [];
  }

  final sorted = List<DateTime>.from(times)..sort();
  final start = sorted.first;
  final end = sorted.last;
  final startMs = start.millisecondsSinceEpoch;
  final endMs = end.millisecondsSinceEpoch;
  if (endMs <= startMs) return const [];

  double pos(DateTime date) =>
      ((date.millisecondsSinceEpoch - startMs) / (endMs - startMs)).clamp(
        0.0,
        1.0,
      );

  List<_DateAxisTick> fromDates(
    Iterable<DateTime> dates,
    String Function(DateTime date) label,
  ) {
    final usedLabels = <String>{};
    final out = <_DateAxisTick>[];
    for (final date in dates) {
      if (date.isBefore(start) || date.isAfter(end)) continue;
      final text = label(date);
      if (!usedLabels.add(text)) continue;
      out.add(_DateAxisTick(t: pos(date), label: text));
    }
    return out;
  }

  switch (period) {
    case ValuationPeriod.diario:
      return const [];
    case ValuationPeriod.semanal:
      return fromDates(sorted, _diaMes);
    case ValuationPeriod.mensal:
      final mondays = <DateTime>[];
      var day = _proximaSegunda(start);
      while (!day.isAfter(end) && mondays.length < 6) {
        mondays.add(day);
        day = day.add(const Duration(days: 7));
      }
      if (mondays.length < 2) {
        return fromDates([start, end], _diaMes);
      }
      return fromDates(mondays, _diaMes);
    case ValuationPeriod.seisMeses:
    case ValuationPeriod.ytd:
      final out = <_DateAxisTick>[];
      final usedLabels = <String>{};
      var cursor = DateTime(start.year, start.month);
      final endMonth = DateTime(end.year, end.month);
      while (!cursor.isAfter(endMonth)) {
        final nextMonth = DateTime(cursor.year, cursor.month + 1);
        if (nextMonth.isAfter(start) && !cursor.isAfter(end)) {
          final visibleDate = cursor.isBefore(start) ? start : cursor;
          final text = _mesCurto(cursor);
          if (usedLabels.add(text)) {
            out.add(_DateAxisTick(t: pos(visibleDate), label: text));
          }
        }
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
      return out;
  }
}

/// Gráfico de área + scrubbing + chips (§5.4). Valores em [series] são genéricos;
/// [formatYAxis] / [formatTooltip] formatam o eixo e o cartão (valuation em M ou BRL).
class ValuationEvolutionChartCard extends StatefulWidget {
  const ValuationEvolutionChartCard({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.series,
    required this.primary,
    this.title = 'Evolução de Valuation',
    this.footnote =
        'Mantenha o dedo sobre o gráfico para ver data, horário e valuation.',
    this.formatYAxis,
    this.formatTooltip,
    this.touchListenerKey = const ValueKey<String>(
      'startup_valuation_chart_touch',
    ),
  });

  final ValuationPeriod selected;
  final ValueChanged<ValuationPeriod> onSelect;
  final ValuationChartSeries series;
  final Color primary;
  final String title;
  final String footnote;
  final String Function(double value)? formatYAxis;
  final String Function(double value)? formatTooltip;
  final ValueKey<String> touchListenerKey;

  @override
  State<ValuationEvolutionChartCard> createState() =>
      _ValuationEvolutionChartCardState();
}

class _ValuationEvolutionChartCardState
    extends State<ValuationEvolutionChartCard> {
  double _t = 0.5;
  bool _fingerOnChart = false;

  @override
  void didUpdateWidget(covariant ValuationEvolutionChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        !identical(oldWidget.series, widget.series)) {
      _fingerOnChart = false;
      _t = 0.5;
    }
  }

  void _atualizaComDx(double dx, double width) {
    if (width <= 0) return;
    setState(() {
      _fingerOnChart = true;
      _t = (dx / width).clamp(0.0, 1.0);
    });
  }

  void _soltaDedo() {
    if (!_fingerOnChart) return;
    setState(() => _fingerOnChart = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = widget.series.valuationMillions;
    final times = widget.series.sampleTimes;
    final dateTicks = _dateAxisTicks(period: widget.selected, times: times);
    final dateTickWidthFactor = dateTicks.isEmpty
        ? 0.0
        : math.min(0.22, 1 / dateTicks.length);
    final n = values.length;
    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    final span = (rawMax - rawMin).abs() < 1e-6 ? 1.0 : (rawMax - rawMin);
    final pad = span * 0.12 + 0.25;
    var vmin = rawMin - pad;
    final vmax = rawMax + pad;
    // Cotações e saldos reais não devem forçar rótulos negativos no eixo.
    if (rawMin >= 0) {
      vmin = math.max(0, vmin);
    }

    String fY(double v) =>
        widget.formatYAxis?.call(v) ?? _defaultYAxisMillion(v);
    String fT(double v) =>
        widget.formatTooltip?.call(v) ?? _defaultTooltipMillion(v);

    const plotHeight = 168.0;
    const axisWidth = 52.0;

    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(kValuationChartCardRadius),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in ValuationPeriod.values) ...[
                    _PeriodChip(
                      label: p.chipLabel,
                      selected: widget.selected == p,
                      primary: widget.primary,
                      onTap: () => widget.onSelect(p),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: plotHeight + (dateTicks.isEmpty ? 0 : 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final plotW = math.max(
                    120.0,
                    constraints.maxWidth - axisWidth,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: axisWidth,
                        height: plotHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(5, (i) {
                            final v = vmax - i * (vmax - vmin) / 4;
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                fY(v),
                                maxLines: 1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: AppColors.secondaryLabel(
                                    theme,
                                  ).withValues(alpha: 0.9),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: plotHeight + (dateTicks.isEmpty ? 0 : 24),
                          child: Column(
                            children: [
                              SizedBox(
                                height: plotHeight,
                                child: Listener(
                                  key: widget.touchListenerKey,
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: (e) =>
                                      _atualizaComDx(e.localPosition.dx, plotW),
                                  onPointerMove: (e) {
                                    if (!_fingerOnChart) return;
                                    _atualizaComDx(e.localPosition.dx, plotW);
                                  },
                                  onPointerUp: (_) => _soltaDedo(),
                                  onPointerCancel: (_) => _soltaDedo(),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CustomPaint(
                                        size: Size(plotW, plotHeight),
                                        painter: _ValuationAreaChartPainter(
                                          values: values,
                                          vmin: vmin,
                                          vmax: vmax,
                                          highlightT: _fingerOnChart
                                              ? _t
                                              : null,
                                          lineColor: const Color(0xFF4F6AF0),
                                          gridColor: AppColors.cardDivider(
                                            theme,
                                          ),
                                          highlightFill:
                                              theme.colorScheme.surface,
                                        ),
                                      ),
                                      if (_fingerOnChart &&
                                          n > 0 &&
                                          times.length == n)
                                        Positioned(
                                          left: AppColors.readingCardStackLeft(
                                            plotWidth: plotW,
                                            t: _t,
                                            minLeft: 0,
                                          ),
                                          top: 4,
                                          child: MesclaChartReadingCard(
                                            dateTimeLine:
                                                formatChartSampleDateTime(
                                                  dateTimeAtT(_t, times),
                                                ),
                                            valueLine: fT(
                                              scalarAtT(_t, values),
                                            ),
                                            minWidth: 145,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (dateTicks.isNotEmpty)
                                SizedBox(
                                  height: 24,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      for (final tick in dateTicks)
                                        Align(
                                          alignment: Alignment(
                                            tick.t * 2 - 1,
                                            0,
                                          ),
                                          child: FractionallySizedBox(
                                            widthFactor: dateTickWidthFactor,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                tick.label,
                                                maxLines: 1,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontSize: 10,
                                                      color:
                                                          AppColors.secondaryLabel(
                                                            theme,
                                                          ).withValues(
                                                            alpha: 0.82,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (widget.footnote.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.footnote,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.secondaryLabel(theme).withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValuationAreaChartPainter extends CustomPainter {
  _ValuationAreaChartPainter({
    required this.values,
    required this.vmin,
    required this.vmax,
    required this.highlightT,
    required this.lineColor,
    required this.gridColor,
    required this.highlightFill,
  });

  final List<double> values;
  final double vmin;
  final double vmax;
  final double? highlightT;
  final Color lineColor;
  final Color gridColor;
  final Color highlightFill;

  List<Offset> _points(Size size) {
    final n = values.length;
    if (n == 0) return [];
    final h = size.height;
    final w = size.width;
    double yPix(double v) {
      final t = (v - vmin) / (vmax - vmin);
      return h * (1.0 - t.clamp(0.0, 1.0));
    }

    return List.generate(n, (i) {
      final x = n == 1 ? w / 2 : (i / (n - 1)) * w;
      return Offset(x, yPix(values[i]));
    });
  }

  Path _smoothLinePath(List<Offset> pts) {
    if (pts.isEmpty) return Path();
    if (pts.length == 1) {
      return Path()..moveTo(pts[0].dx, pts[0].dy);
    }
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[0] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;

    for (var i = 0; i <= 4; i++) {
      final y = h * (i / 4);
      final p = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, y), Offset(w, y), p);
    }

    final pts = _points(size);
    if (pts.isEmpty) return;

    final linePath = _smoothLinePath(pts);

    final fillPath = Path()..addPath(linePath, Offset.zero);
    fillPath.lineTo(pts.last.dx, h);
    fillPath.lineTo(pts.first.dx, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(Offset(w / 2, 0), Offset(w / 2, h), [
        lineColor.withValues(alpha: 0.32),
        lineColor.withValues(alpha: 0.04),
      ]);
    canvas.drawPath(fillPath, fillPaint);

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..isAntiAlias = true,
    );

    final ht = highlightT;
    if (ht != null && values.isNotEmpty) {
      final t = ht.clamp(0.0, 1.0);
      final vx = scalarAtT(t, values);
      final x = t * w;
      double yPix(double v) {
        final tp = (v - vmin) / (vmax - vmin);
        return h * (1.0 - tp.clamp(0.0, 1.0));
      }

      final y = yPix(vx);
      final guia = Paint()
        ..color = lineColor.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, h), guia);

      final fill = Paint()..color = highlightFill;
      canvas.drawCircle(Offset(x, y), 7, fill);
      final borda = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(x, y), 7, borda);
    }
  }

  @override
  bool shouldRepaint(covariant _ValuationAreaChartPainter oldDelegate) {
    return !identical(oldDelegate.values, values) ||
        oldDelegate.vmin != vmin ||
        oldDelegate.vmax != vmax ||
        oldDelegate.highlightT != highlightT ||
        oldDelegate.highlightFill != highlightFill;
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
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
          : AppColors.themeMutedSurface(theme),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? primary : AppColors.secondaryLabel(theme),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
