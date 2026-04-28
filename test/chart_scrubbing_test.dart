// Testes unitários da interpolação e formatação usadas nos gráficos
// (detalhes da startup + carteira).
//
// Correm com: flutter test test/chart_scrubbing_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/widgets/chart_scrubbing.dart';

void main() {
  group('scalarAtT', () {
    test('lista vazia devolve 0', () {
      expect(scalarAtT(0.5, []), 0);
    });

    test('um único elemento ignora t', () {
      expect(scalarAtT(0, [3.5]), 3.5);
      expect(scalarAtT(1, [3.5]), 3.5);
    });

    test('interpola linearmente entre dois pontos', () {
      expect(scalarAtT(0, [10.0, 20.0]), 10);
      expect(scalarAtT(1, [10.0, 20.0]), 20);
      expect(scalarAtT(0.5, [10.0, 20.0]), 15);
    });

    test('t=0.5 com três pontos corresponde ao ponto médio da polyline', () {
      expect(scalarAtT(0.5, [0.0, 10.0, 20.0]), 10);
    });
  });

  group('dateTimeAtT', () {
    test('lista vazia devolve época zero', () {
      final dt = dateTimeAtT(0.5, []);
      expect(dt.millisecondsSinceEpoch, 0);
    });

    test('interpola milissegundos entre dois instantes', () {
      final a = DateTime(2026, 4, 8, 10, 0);
      final b = DateTime(2026, 4, 8, 12, 0);
      final mid = dateTimeAtT(0.5, [a, b]);
      expect(mid.hour, 11);
      expect(mid.minute, 0);
    });
  });

  group('formatChartSampleDateTime', () {
    test('formata dia, mês abreviado PT, ano e HH:mm', () {
      expect(
        formatChartSampleDateTime(DateTime(2026, 4, 16, 17, 42)),
        '16 abr 2026 · 17:42',
      );
    });

    test('zero-padding em dia e minutos', () {
      expect(
        formatChartSampleDateTime(DateTime(2026, 1, 5, 9, 8)),
        '05 jan 2026 · 09:08',
      );
    });
  });
}
