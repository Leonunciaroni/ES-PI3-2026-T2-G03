// Testes do cartão de leitura partilhado pelos gráficos.
//
// Correm com: flutter test test/mescla_chart_reading_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/theme/app_colors.dart';
import 'package:pi_iii/widgets/mescla_chart_reading_card.dart';

Widget _wrap(Widget child) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.seedPurple,
    brightness: Brightness.light,
  );
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('MesclaChartReadingCard', () {
    testWidgets('mostra data/hora e valor nas duas linhas', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MesclaChartReadingCard(
            dateTimeLine: '16 abr 2026 · 17:42',
            valueLine: 'R\$ 21,50 mi',
          ),
        ),
      );

      expect(find.text('16 abr 2026 · 17:42'), findsOneWidget);
      expect(find.text('R\$ 21,50 mi'), findsOneWidget);
    });

    testWidgets('usa Material com elevação (tooltip legível)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MesclaChartReadingCard(
            dateTimeLine: '01 jan 2026 · 00:00',
            valueLine: 'R\$ 0,00',
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(MesclaChartReadingCard),
          matching: find.byType(Material),
        ),
      );
      expect(material.elevation, 4);
    });
  });
}
