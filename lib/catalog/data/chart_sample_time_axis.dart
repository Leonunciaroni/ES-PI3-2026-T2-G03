// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Eixo temporal dos gráficos (valuation / cotação): janelas ancoradas em [now]
// local, sem dependência circular com o mock de detalhe — usa o índice do enum
// [ValuationPeriod] (0=diario … 4=ytd).

/// Início inclusivo da janela do chip, na mesma ordem de [ValuationPeriod.values].
DateTime chartWindowStartForPeriodIndex(int periodIndex, DateTime now) {
  switch (periodIndex) {
    case 0:
      return now.subtract(const Duration(hours: 24));
    case 1:
      return now.subtract(const Duration(days: 42));
    case 2:
      return now.subtract(const Duration(days: 120));
    case 3:
      return now.subtract(const Duration(days: 183));
    case 4:
      return DateTime(now.year, 1, 1);
    default:
      return now.subtract(const Duration(hours: 24));
  }
}

List<DateTime> chartEvenlySpacedTimes(DateTime start, DateTime end, int count) {
  if (count <= 0) return const [];
  if (count == 1) return <DateTime>[end];
  final ms0 = start.millisecondsSinceEpoch;
  final ms1 = end.millisecondsSinceEpoch;
  return List<DateTime>.generate(count, (int i) {
    final w = i / (count - 1);
    return DateTime.fromMillisecondsSinceEpoch(
      (ms0 + (ms1 - ms0) * w).round(),
    );
  });
}
