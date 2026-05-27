// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Séries de **cotação BRL/token** para o Balcão. Janelas dos chips = mesma lógica
// que a evolução de saldo na Carteira (dias civis e 7/30/180, YTD).
// Quando existe `seriesDiario` da Cloud Function [getStartupMarketStats], usa-se
// essa história; caso contrário gera-se eixo temporal sintético a partir do mock
// de detalhe, evitando datas fixas de 2026 desalinhadas entre chips.

import '../catalog/data/chart_sample_time_axis.dart';
import '../catalog/data/startup_detail_mock.dart';

/// Converte o array `seriesDiario` devolvido por [getStartupMarketStats].
List<BalcaoMarketPricePoint>? balcaoParseSeriesDiarioJson(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  final out = <BalcaoMarketPricePoint>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final tIso = m['tIso'];
    if (tIso is! String || tIso.isEmpty) continue;
    final t = DateTime.tryParse(tIso.trim());
    if (t == null) continue;
    final pb = m['priceBrl'];
    final double? price = switch (pb) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.trim().replaceAll(',', '.')),
      _ => null,
    };
    if (price == null || !price.isFinite || price <= 0) continue;
    out.add(BalcaoMarketPricePoint(t.toLocal(), price));
  }
  if (out.length < 2) return null;
  return balcaoSortAndDedupePoints(out);
}

/// Ponto (t, preço) na curva de mercado simulado.
class BalcaoMarketPricePoint {
  const BalcaoMarketPricePoint(this.t, this.priceBrl);

  final DateTime t;
  final double priceBrl;
}

/// Início (inclusivo) da janela de cada chip — delega a [chartPeriodWindowStart].
DateTime balcaoPeriodWindowStart(ValuationPeriod p, DateTime now) =>
    chartPeriodWindowStart(p, now);

List<double> _scaleToAnchor(List<double> values, double anchorBrl) {
  if (values.isEmpty) return const [];
  final last = values.last;
  if (last.abs() < 1e-12) {
    return List<double>.filled(values.length, anchorBrl);
  }
  return values.map((e) => anchorBrl * (e / last)).toList();
}

/// Garante lista ordenada por tempo e remove duplicados no mesmo ms.
List<BalcaoMarketPricePoint> balcaoSortAndDedupePoints(
  List<BalcaoMarketPricePoint> raw,
) {
  final sorted = List<BalcaoMarketPricePoint>.from(raw)
    ..sort((a, b) => a.t.compareTo(b.t));
  if (sorted.isEmpty) return sorted;
  final out = <BalcaoMarketPricePoint>[sorted.first];
  for (var i = 1; i < sorted.length; i++) {
    final p = sorted[i];
    if (p.t.millisecondsSinceEpoch == out.last.t.millisecondsSinceEpoch) {
      out[out.length - 1] = p;
    } else {
      out.add(p);
    }
  }
  return out;
}

/// Último instante = [now]; último preço = [precoAtualBrl] (cotação publicada).
List<BalcaoMarketPricePoint> balcaoExtendSeriesToNow(
  List<BalcaoMarketPricePoint> sortedAsc,
  DateTime nowLocal,
  double precoAtualBrl,
) {
  if (!precoAtualBrl.isFinite || precoAtualBrl <= 0) {
    return sortedAsc;
  }
  if (sortedAsc.isEmpty) {
    return <BalcaoMarketPricePoint>[
      BalcaoMarketPricePoint(nowLocal.subtract(const Duration(hours: 24)), precoAtualBrl),
      BalcaoMarketPricePoint(nowLocal, precoAtualBrl),
    ];
  }
  final out = List<BalcaoMarketPricePoint>.from(sortedAsc);
  final last = out.last;
  final lastMs = last.t.millisecondsSinceEpoch;
  final nowMs = nowLocal.millisecondsSinceEpoch;
  if (nowMs <= lastMs + 500) {
    out[out.length - 1] = BalcaoMarketPricePoint(last.t, precoAtualBrl);
  } else {
    out.add(BalcaoMarketPricePoint(nowLocal, precoAtualBrl));
  }
  return out;
}

double? balcaoInterpolatePriceBrl(
  List<BalcaoMarketPricePoint> seriesAsc,
  DateTime target,
) {
  if (seriesAsc.isEmpty) return null;
  final x = target.millisecondsSinceEpoch;
  final first = seriesAsc.first;
  final last = seriesAsc.last;
  final xf = first.t.millisecondsSinceEpoch;
  final xl = last.t.millisecondsSinceEpoch;
  if (x <= xf) return first.priceBrl;
  if (x >= xl) return last.priceBrl;
  for (var i = 0; i < seriesAsc.length - 1; i++) {
    final a = seriesAsc[i];
    final b = seriesAsc[i + 1];
    final ta = a.t.millisecondsSinceEpoch;
    final tb = b.t.millisecondsSinceEpoch;
    if (x >= ta && x <= tb) {
      if (tb <= ta) return a.priceBrl;
      final w = (x - ta) / (tb - ta);
      return a.priceBrl + w * (b.priceBrl - a.priceBrl);
    }
  }
  return last.priceBrl;
}

/// Espelha [statsLastWindowHours] do Node: janela móvel ancorada no **último** ponto.
({double? changePct24h, double? minBrl, double? maxBrl}) balcaoStats24hRolling(
  List<BalcaoMarketPricePoint> seriesAsc, {
  int windowHours = 24,
}) {
  if (seriesAsc.length < 2) {
    return (changePct24h: null, minBrl: null, maxBrl: null);
  }
  final last = seriesAsc.last;
  final anchor = last.t.millisecondsSinceEpoch;
  final start = anchor - windowHours * 3600 * 1000;
  final refPrice = balcaoInterpolatePriceBrl(seriesAsc, DateTime.fromMillisecondsSinceEpoch(start));
  final endPrice = last.priceBrl;
  double? changePct;
  if (refPrice != null &&
      refPrice.isFinite &&
      refPrice.abs() > 1e-12 &&
      endPrice.isFinite) {
    final p = ((endPrice - refPrice) / refPrice) * 100.0;
    changePct = p.isFinite ? p : null;
  }
  final candidates = <double>[endPrice];
  if (refPrice != null && refPrice.isFinite) {
    candidates.add(refPrice);
  }
  for (final pt in seriesAsc) {
    final tx = pt.t.millisecondsSinceEpoch;
    if (tx >= start && tx <= anchor) {
      candidates.add(pt.priceBrl);
    }
  }
  if (candidates.isEmpty) {
    return (changePct24h: changePct, minBrl: null, maxBrl: null);
  }
  return (
    changePct24h: changePct,
    minBrl: candidates.reduce((a, b) => a < b ? a : b),
    maxBrl: candidates.reduce((a, b) => a > b ? a : b),
  );
}

List<BalcaoMarketPricePoint> _downsample(
  List<BalcaoMarketPricePoint> pts,
  int maxPoints,
) {
  if (pts.length <= maxPoints) return pts;
  final n = pts.length;
  final out = <BalcaoMarketPricePoint>[];
  for (var k = 0; k < maxPoints; k++) {
    final idx = ((n - 1) * k / (maxPoints - 1)).round().clamp(0, n - 1);
    out.add(pts[idx]);
  }
  return out;
}

/// Série BRL/token para o gráfico: valores em [valuationMillions] (nome legado).
ValuationChartSeries balcaoCotacaoSeriesForPeriod({
  required ValuationPeriod period,
  required DateTime nowLocal,
  required double precoMercadoBrl,
  List<BalcaoMarketPricePoint>? serverPoints,
  required StartupDetailViewData detailFallback,
  int maxPoints = 48,
}) {
  if (serverPoints != null &&
      serverPoints.length >= 2 &&
      precoMercadoBrl > 1e-12) {
    final sorted = balcaoSortAndDedupePoints(serverPoints);
    final extended = balcaoExtendSeriesToNow(sorted, nowLocal, precoMercadoBrl);
    final start = balcaoPeriodWindowStart(period, nowLocal);
    var windowed = extended.where((p) => !p.t.isBefore(start)).toList();
    if (windowed.length < 2) {
      final p0 = balcaoInterpolatePriceBrl(extended, start) ?? precoMercadoBrl;
      windowed = <BalcaoMarketPricePoint>[
        BalcaoMarketPricePoint(start, p0),
        BalcaoMarketPricePoint(nowLocal, precoMercadoBrl),
      ];
    }
    final sampled = _downsample(windowed, maxPoints);
    return ValuationChartSeries(
      valuationMillions: sampled.map((e) => e.priceBrl).toList(),
      sampleTimes: sampled.map((e) => e.t).toList(),
    );
  }

  final shape = detailFallback.chartSeriesByPeriod[period]!;
  final y = _scaleToAnchor(shape.valuationMillions, precoMercadoBrl);
  final t0 = balcaoPeriodWindowStart(period, nowLocal);
  final times = chartEvenlySpacedTimes(t0, nowLocal, y.length);
  return ValuationChartSeries(valuationMillions: y, sampleTimes: times);
}
