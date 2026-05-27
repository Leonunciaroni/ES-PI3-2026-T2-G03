import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/catalog/data/startup_detail_mock.dart';
import 'package:mescla_invest/widgets/chart_date_axis_ticks.dart';

void main() {
  group('chartDateAxisTicks', () {
    test('diario retorna vazio', () {
      final ticks = chartDateAxisTicks(
        period: ValuationPeriod.diario,
        times: [
          DateTime(2026, 3, 1),
          DateTime(2026, 3, 2),
        ],
      );
      expect(ticks, isEmpty);
    });

    test('seis meses usa ultimos 6 meses civis a partir do fim da serie', () {
      final ticks = chartDateAxisTicks(
        period: ValuationPeriod.seisMeses,
        times: [
          DateTime(2025, 11, 20),
          DateTime(2026, 5, 10),
        ],
      );
      expect(ticks.map((t) => t.label).toList(), [
        'dez',
        'jan',
        'fev',
        'mar',
        'abr',
        'mai',
      ]);
    });

    test('ytd lista meses do ano ate o fim', () {
      final ticks = chartDateAxisTicks(
        period: ValuationPeriod.ytd,
        times: [
          DateTime(2026, 1, 5),
          DateTime(2026, 5, 5),
        ],
      );
      expect(ticks.map((t) => t.label).toList(), [
        'jan',
        'fev',
        'mar',
        'abr',
        'mai',
      ]);
    });

    test('mensal inclui segundas-feiras da janela de 30 dias', () {
      final agora = DateTime(2026, 3, 31, 14, 0);
      final ticks = chartDateAxisTicks(
        period: ValuationPeriod.mensal,
        times: [
          DateTime(2026, 3, 1),
          DateTime(2026, 3, 31),
        ],
        now: agora,
      );
      final labels = ticks.map((t) => t.label).toList();
      expect(labels, contains('02/03'));
      expect(labels, contains('30/03'));
      expect(labels.length, lessThanOrEqualTo(5));
    });

    test('mensal mesmo eixo com serie esparsa ou densa (balcao vs carteira)', () {
      final agora = DateTime(2026, 4, 14, 16, 0);
      final esparsa = chartDateAxisTicks(
        period: ValuationPeriod.mensal,
        times: [DateTime(2026, 3, 20), agora],
        now: agora,
      );
      final densa = chartDateAxisTicks(
        period: ValuationPeriod.mensal,
        times: List<DateTime>.generate(
          48,
          (i) => agora.subtract(Duration(hours: i * 12)),
        ),
        now: agora,
      );
      expect(
        esparsa.map((t) => t.label).toList(),
        densa.map((t) => t.label).toList(),
      );
    });
  });
}
