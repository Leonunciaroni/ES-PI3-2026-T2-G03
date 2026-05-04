// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Testes de widget focados na tela de detalhes da startup.
//
// Correm com: flutter test test/startup_detail_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/catalog/data/startup_detail_mock.dart';
import 'package:mescla_invest/catalog/models/catalog_startup.dart';
import 'package:mescla_invest/catalog/models/startup_detail_load_state.dart';
import 'package:mescla_invest/catalog/screens/startup_detail_screen.dart';
import 'package:mescla_invest/theme/app_colors.dart';

/// Igual ao preview GreenFlow, com [firestoreId] para o fluxo “Fazer pergunta” abrir o diálogo.
const CatalogStartup kCatalogGreenFlowComId = CatalogStartup(
  name: 'GreenFlow',
  category: 'AGROTECH',
  stage: StartupStage.nova,
  yieldPercentLabel: '+18.5%',
  tokenPrice: 15.30,
  description: 'Soluções de automações para a sua colheita',
  captureProgress: 0.8,
  logoColor: Color(0xFF22C55E),
  logoIcon: Icons.eco_outlined,
  firestoreId: 'test_startup_pergunta',
);

/// [MaterialApp] mínimo com o mesmo tema roxo do app, para a tela usar cores corretas.
Widget _wrapStartupDetailScreen() {
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
    home: StartupDetailScreen(catalog: kPreviewCatalogStartup),
  );
}

void main() {
  group('StartupDetailScreen', () {
    testWidgets('mostra CTA Investir e nome da startup', (tester) async {
      await tester.pumpWidget(_wrapStartupDetailScreen());
      await tester.pumpAndSettle();

      expect(find.text('Investir Agora'), findsOneWidget);
      expect(find.text('GreenFlow'), findsOneWidget);
    });

    testWidgets('Membros-Chave tem Saber mais em cada linha', (tester) async {
      await tester.pumpWidget(_wrapStartupDetailScreen());
      await tester.pumpAndSettle();

      expect(find.text('Membros-Chave'), findsOneWidget);
      expect(find.text('Saber mais'), findsNWidgets(3));
    });

    testWidgets(
      'Nova pergunta: investidor vê SegmentedButton Pública/Privada',
      (tester) async {
        final colorScheme = ColorScheme.fromSeed(
          seedColor: AppColors.seedPurple,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.seedPurple,
          onPrimary: const Color(0xFFFFFFFF),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: colorScheme,
              scaffoldBackgroundColor: AppColors.gradientBottom,
            ),
            home: StartupDetailScreen(
              catalog: kCatalogGreenFlowComId,
              detailLoadStreamForTesting:
                  Stream<StartupDetailLoadState>.value(
                StartupDetailReady(
                  startupDetailForWithPrivateQuestions(
                    kCatalogGreenFlowComId,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Fazer pergunta'),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Fazer pergunta'));
        await tester.tap(find.text('Fazer pergunta'));
        await tester.pumpAndSettle();

        expect(find.text('Nova pergunta'), findsOneWidget);
        expect(find.text('Visibilidade'), findsOneWidget);
        expect(find.byType(SegmentedButton<bool>), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SegmentedButton<bool>),
            matching: find.text('Pública'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SegmentedButton<bool>),
            matching: find.text('Privada'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
