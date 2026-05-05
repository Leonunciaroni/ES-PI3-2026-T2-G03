// Testes de widget do separador Balcão (lista + mesa + diálogo).
//
// Correm com: flutter test test/balcao_tab_screen_test.dart
//
// Usamos [BalcaoTabScreen.startupsFutureForTesting] para não depender das Functions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/balcao/screens/balcao_tab_screen.dart';
import 'package:mescla_invest/catalog/models/catalog_startup.dart';
import 'package:mescla_invest/theme/app_colors.dart';

/// Duplicado do mock do catálogo — mantém o teste isolado e previsível.
const List<CatalogStartup> _kBalcaoMockStartups = <CatalogStartup>[
  CatalogStartup(
    name: 'GreenFlow',
    category: 'AGROTECH',
    stage: StartupStage.nova,
    yieldPercentLabel: '+18.5%',
    tokenPrice: 15.30,
    description: 'Mock',
    captureProgress: 0.8,
    logoColor: Color(0xFF22C55E),
    logoIcon: Icons.eco_outlined,
    sigla: 'GFLO',
  ),
  CatalogStartup(
    name: 'CyberMesh',
    category: 'CYBERSECURITY',
    stage: StartupStage.emOperacao,
    yieldPercentLabel: '+12.3%',
    tokenPrice: 42.00,
    description: 'Mock',
    captureProgress: 0.55,
    logoColor: Color(0xFF18181B),
    logoIcon: Icons.security_outlined,
  ),
];

Widget _wrapBalcaoTabScreen() {
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
    ),
    home: BalcaoTabScreen(
      startupsFutureForTesting: Future<List<CatalogStartup>>.value(
        _kBalcaoMockStartups,
      ),
    ),
  );
}

void main() {
  group('BalcaoTabScreen', () {
    testWidgets('mostra título Balcão e startups do mock', (tester) async {
      await tester.pumpWidget(_wrapBalcaoTabScreen());
      await tester.pumpAndSettle();

      expect(find.text('Balcão'), findsOneWidget);
      expect(find.text('GFLO'), findsAtLeastNWidgets(1));
      expect(find.text('CyberMesh'), findsOneWidget);
    });

    testWidgets('toque na startup abre mesa com Comprar e lista do dia', (tester) async {
      await tester.pumpWidget(_wrapBalcaoTabScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('GFLO').first);
      await tester.pumpAndSettle();

      expect(find.text('GFLO / BRL'), findsOneWidget);
      expect(find.text('GreenFlow'), findsWidgets);
      expect(find.text('Histórico de cotação'), findsOneWidget);
      expect(find.text('Comprar'), findsOneWidget);
      expect(find.text('Vender'), findsOneWidget);
      expect(find.text('Transações de hoje'), findsOneWidget);
    });

    testWidgets(
      'Comprar abre quantidade, Continuar, modal e senha',
      (tester) async {
      await tester.pumpWidget(_wrapBalcaoTabScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('GFLO').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Comprar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comprar'));
      await tester.pumpAndSettle();

      expect(find.text('Valor do investimento'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Deseja confirmar o investimento de'),
        findsOneWidget,
      );

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar compra'), findsWidgets);
      expect(find.text('Senha do login'), findsOneWidget);
    });
  });
}
