// Marcos do eixo X dos gráficos de evolução (valuation, saldo, cotação).
// Consumido por [ValuationEvolutionChartCard] — único ponto para todos os gráficos.

import '../catalog/data/chart_sample_time_axis.dart';
import '../catalog/data/startup_detail_mock.dart';

const kChartMonthLabelsPt = <String>[
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

/// Rótulo de uma coluna do eixo de datas (distribuição uniforme, sem sobreposição).
class ChartDateAxisTick {
  const ChartDateAxisTick({required this.label});

  final String label;
}

String chartAxisDiaMes(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

String chartAxisMesCurto(DateTime date) => kChartMonthLabelsPt[date.month - 1];

DateTime _inicioDia(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _proximaSegunda(DateTime date) {
  final base = _inicioDia(date);
  final diasAteSegunda = (DateTime.monday - base.weekday) % 7;
  return base.add(Duration(days: diasAteSegunda));
}

List<DateTime> _diasCivisEntre(DateTime start, DateTime end) {
  final out = <DateTime>[];
  var day = _inicioDia(start);
  final last = _inicioDia(end);
  while (!day.isAfter(last)) {
    out.add(day);
    day = day.add(const Duration(days: 1));
  }
  return out;
}

/// Mantém primeiro e último; amostra [maxCount] itens uniformemente no índice.
List<T> _amostraUniforme<T>(List<T> items, int maxCount) {
  if (maxCount <= 0 || items.isEmpty) return const [];
  if (items.length <= maxCount) return items;
  if (maxCount == 1) return <T>[items.first];

  final out = <T>[];
  for (var i = 0; i < maxCount; i++) {
    final idx = (i * (items.length - 1) / (maxCount - 1)).round();
    final item = items[idx];
    if (out.isEmpty || out.last != item) {
      out.add(item);
    }
  }
  return out;
}

/// Últimos [n] meses civis completos, terminando no mês de [end] (inclusivo).
List<DateTime> chartAxisUltimosMesesCalendario(DateTime end, int n) {
  assert(n >= 1);
  final out = <DateTime>[];
  var y = end.year;
  var m = end.month;
  for (var i = 0; i < n; i++) {
    out.add(DateTime(y, m, 1));
    m--;
    if (m < 1) {
      m = 12;
      y--;
    }
  }
  return out.reversed.toList();
}

/// Meses de janeiro até o mês de [end], no ano de [end].
List<DateTime> chartAxisMesesYtd(DateTime end) {
  return List<DateTime>.generate(
    end.month,
    (i) => DateTime(end.year, i + 1, 1),
  );
}

/// DIÁRIO: sem marcos. SEMANAL/MENSAL: janela 7/30 dias civis a partir de [now]
/// (igual Carteira e Balcão), não o 1º/último ponto da série. 6M/YTD: meses civis.
List<ChartDateAxisTick> chartDateAxisTicks({
  required ValuationPeriod period,
  required List<DateTime> times,
  DateTime? now,
}) {
  if (period == ValuationPeriod.diario || times.length < 2) {
    return const [];
  }

  final sorted = List<DateTime>.from(times)..sort();
  final anchorNow = now ?? sorted.last;
  final windowStart = chartPeriodWindowStart(period, anchorNow);
  final windowEnd = anchorNow;

  switch (period) {
    case ValuationPeriod.diario:
      return const [];
    case ValuationPeriod.semanal:
      final dias = _diasCivisEntre(windowStart, windowEnd);
      final escolhidos = _amostraUniforme(dias, 5);
      return [
        for (final d in escolhidos) ChartDateAxisTick(label: chartAxisDiaMes(d)),
      ];
    case ValuationPeriod.mensal:
      final segundas = <DateTime>[];
      var cursor = _proximaSegunda(windowStart);
      while (!cursor.isAfter(windowEnd)) {
        segundas.add(cursor);
        cursor = cursor.add(const Duration(days: 7));
      }
      if (segundas.length < 2) {
        return [
          ChartDateAxisTick(label: chartAxisDiaMes(windowStart)),
          ChartDateAxisTick(label: chartAxisDiaMes(windowEnd)),
        ];
      }
      final escolhidas = _amostraUniforme(segundas, 5);
      return [
        for (final d in escolhidas) ChartDateAxisTick(label: chartAxisDiaMes(d)),
      ];
    case ValuationPeriod.seisMeses:
      final meses = chartAxisUltimosMesesCalendario(anchorNow, 6);
      return [
        for (final m in meses) ChartDateAxisTick(label: chartAxisMesCurto(m)),
      ];
    case ValuationPeriod.ytd:
      final todos = chartAxisMesesYtd(anchorNow);
      final meses = todos.length <= 6 ? todos : _amostraUniforme(todos, 6);
      return [
        for (final m in meses) ChartDateAxisTick(label: chartAxisMesCurto(m)),
      ];
  }
}
