// Gestos nos gráficos de evolução (startup + carteira): mostrador ao arrastar.
//
// Correm com: flutter test test/chart_interaction_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/carteira/screens/carteira_screen.dart';
import 'package:mescla_invest/catalog/data/startup_detail_mock.dart';
import 'package:mescla_invest/catalog/screens/startup_detail_screen.dart';
import 'package:mescla_invest/theme/app_colors.dart';
import 'package:mescla_invest/widgets/mescla_chart_reading_card.dart';
import 'package:mescla_invest/widgets/valuation_evolution_chart_card.dart';

Widget _themedApp(Widget home) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.seedPurple,
    brightness: Brightness.light,
  ).copyWith(primary: AppColors.seedPurple, onPrimary: const Color(0xFFFFFFFF));

  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.gradientBottom,
    ),
    home: home,
  );
}

void main() {
  group('ValuationEvolutionChartCard - eixo de datas', () {
    testWidgets('mensal mostra segundas-feiras e diario nao mostra datas', (
      tester,
    ) async {
      final monthlySeries = ValuationChartSeries(
        valuationMillions: const [10, 11, 12, 13, 14],
        sampleTimes: [
          DateTime(2026, 3),
          DateTime(2026, 3, 8),
          DateTime(2026, 3, 16),
          DateTime(2026, 3, 24),
          DateTime(2026, 3, 31),
        ],
      );

      await tester.pumpWidget(
        _themedApp(
          ValuationEvolutionChartCard(
            selected: ValuationPeriod.mensal,
            onSelect: (_) {},
            series: monthlySeries,
            primary: AppColors.seedPurple,
            footnote: '',
          ),
        ),
      );

      expect(find.text('02/03'), findsOneWidget);
      expect(find.text('09/03'), findsOneWidget);
      expect(find.text('16/03'), findsOneWidget);
      expect(find.text('23/03'), findsOneWidget);
      expect(find.text('30/03'), findsOneWidget);

      await tester.pumpWidget(
        _themedApp(
          ValuationEvolutionChartCard(
            selected: ValuationPeriod.diario,
            onSelect: (_) {},
            series: monthlySeries,
            primary: AppColors.seedPurple,
            footnote: '',
          ),
        ),
      );

      expect(find.text('02/03'), findsNothing);
      expect(find.text('09/03'), findsNothing);
    });

    testWidgets('seis meses mostra nomes dos meses', (tester) async {
      final series = ValuationChartSeries(
        valuationMillions: const [10, 11, 12, 13, 14, 15],
        sampleTimes: [
          DateTime(2026, 1, 5),
          DateTime(2026, 2, 5),
          DateTime(2026, 3, 5),
          DateTime(2026, 4, 5),
          DateTime(2026, 5, 5),
          DateTime(2026, 6, 5),
        ],
      );

      await tester.pumpWidget(
        _themedApp(
          ValuationEvolutionChartCard(
            selected: ValuationPeriod.seisMeses,
            onSelect: (_) {},
            series: series,
            primary: AppColors.seedPurple,
            footnote: '',
          ),
        ),
      );

      expect(find.text('jan'), findsOneWidget);
      expect(find.text('fev'), findsOneWidget);
      expect(find.text('mar'), findsOneWidget);
      expect(find.text('abr'), findsOneWidget);
      expect(find.text('mai'), findsOneWidget);
      expect(find.text('jun'), findsOneWidget);
    });
  });

  group('StartupDetailScreen — gráfico de valuation', () {
    testWidgets(
      'rodapé indica data, horário e valuation; toque mostra MesclaChartReadingCard',
      (tester) async {
        await tester.pumpWidget(
          _themedApp(StartupDetailScreen(catalog: kPreviewCatalogStartup)),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Mantenha o dedo sobre o gráfico para ver data, horário e valuation.',
          ),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Evolução de Valuation'));

        final chartTouch = find.byKey(
          const ValueKey<String>('startup_valuation_chart_touch'),
        );
        expect(chartTouch, findsOneWidget);

        final chartCenter = tester.getCenter(chartTouch);
        final gesture = await tester.startGesture(chartCenter);
        await tester.pump();

        expect(find.byType(MesclaChartReadingCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(MesclaChartReadingCard),
            matching: find.byType(Text),
          ),
          findsNWidgets(2),
        );
        expect(
          find.descendant(
            of: find.byType(MesclaChartReadingCard),
            matching: find.textContaining('·'),
          ),
          findsOneWidget,
        );

        await gesture.up();
        await tester.pump();

        expect(find.byType(MesclaChartReadingCard), findsNothing);
      },
    );
  });

  group('CarteiraScreen — gráfico de saldo', () {
    testWidgets(
      'toque no gráfico mostra MesclaChartReadingCard com data e valor em R\$',
      (tester) async {
        await tester.pumpWidget(
          _themedApp(
            const CarteiraScreen(
              wrapWithSafeArea: false,
              usarFirebaseParaSessao: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.text('Evolução do Saldo Total Investido'),
        );

        final chartTouch = find.byKey(
          const ValueKey<String>('carteira_saldo_chart_touch'),
        );
        expect(chartTouch, findsOneWidget);

        final chartCenter = tester.getCenter(chartTouch);
        final gesture = await tester.startGesture(chartCenter);
        await tester.pump();

        expect(find.byType(MesclaChartReadingCard), findsOneWidget);
        expect(find.textContaining('R\$'), findsWidgets);

        await gesture.up();
        await tester.pump();

        expect(find.byType(MesclaChartReadingCard), findsNothing);
      },
    );
  });
}
