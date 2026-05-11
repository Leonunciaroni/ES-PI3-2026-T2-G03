// Interpolação contínua no eixo X para leitura de gráficos (protótipo).

/// Interpola lista de doubles no parâmetro [t] ∈ [0, 1], nos mesmos moldes
/// da evolução de saldo na carteira.
double scalarAtT(double t, List<double> values) {
  if (values.isEmpty) return 0;
  if (values.length == 1) return values[0].clamp(0.0, double.infinity);
  final n = values.length;
  final tf = (t * (n - 1)).clamp(0.0, n - 1.0);
  final i0 = tf.floor();
  final i1 = (i0 + 1).clamp(0, n - 1);
  final l = tf - i0;
  final y0 = values[i0];
  final y1 = values[i1];
  if (i0 == i1) return y0;
  return y0 * (1 - l) + y1 * l;
}

/// Interpola instantes entre amostras (eixo temporal contínuo ao arrastar).
DateTime dateTimeAtT(double t, List<DateTime> samples) {
  if (samples.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  if (samples.length == 1) return samples[0];
  final n = samples.length;
  final tf = (t * (n - 1)).clamp(0.0, n - 1.0);
  final i0 = tf.floor();
  final i1 = (i0 + 1).clamp(0, n - 1);
  final l = tf - i0;
  final ms0 = samples[i0].millisecondsSinceEpoch;
  final ms1 = samples[i1].millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch(
    (ms0 * (1 - l) + ms1 * l).round(),
  );
}

const _mesesAbrPt = <String>[
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

/// Formato unificado para o cartão de leitura: `16 abr 2026 · 17:42`.
String formatChartSampleDateTime(DateTime dt) {
  final loc = dt.toLocal();
  final d = loc.day.toString().padLeft(2, '0');
  final mes = _mesesAbrPt[loc.month - 1];
  final y = loc.year.toString();
  final h = loc.hour.toString().padLeft(2, '0');
  final min = loc.minute.toString().padLeft(2, '0');
  return '$d $mes $y · $h:$min';
}
