// Gestos nos gráficos de evolução (startup + carteira): mostrador ao arrastar.
//
// Correm com: flutter test test/chart_interaction_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/carteira/screens/carteira_screen.dart';
import 'package:pi_iii/catalog/data/startup_detail_mock.dart';
import 'package:pi_iii/catalog/screens/startup_detail_screen.dart';
import 'package:pi_iii/theme/app_colors.dart';
import 'package:pi_iii/widgets/mescla_chart_reading_card.dart';

Widget _themedApp(Widget home) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.seedPurple,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.seedPurple,
    onPrimary: const Color(0xFFFFFFFF),
  );

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
  group('StartupDetailScreen — gráfico de valuation', () {
    testWidgets(
      'rodapé indica data, horário e valuation; toque mostra MesclaChartReadingCard',
      (tester) async {
        await tester.pumpWidget(
          _themedApp(
            StartupDetailScreen(data: startupDetailFor(kPreviewCatalogStartup)),
          ),
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
          _themedApp(const CarteiraScreen(wrapWithSafeArea: false)),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Evolução de Saldo'));

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
