// Testes de widget focados na tela Explorar (catálogo).
//
// Correm com: flutter test test/catalog_screen_test.dart
//
// Usamos [CatalogScreen.startupsStreamForTesting] para não depender do Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/catalog/models/catalog_startup.dart';
import 'package:pi_iii/catalog/screens/catalog_screen.dart';
import 'package:pi_iii/theme/app_colors.dart';

/// Mesmas três startups que existiam como mock na tela antes do Firestore.
const List<CatalogStartup> kCatalogMockStartups = <CatalogStartup>[
  CatalogStartup(
    name: 'GreenFlow',
    category: 'AGROTECH',
    stage: StartupStage.nova,
    yieldPercentLabel: '+18.5%',
    tokenPrice: 15.30,
    description: 'Soluções de automações para a sua colheita',
    captureProgress: 0.8,
    logoColor: Color(0xFF22C55E),
    logoIcon: Icons.eco_outlined,
  ),
  CatalogStartup(
    name: 'CyberMesh',
    category: 'CYBERSECURITY',
    stage: StartupStage.emOperacao,
    yieldPercentLabel: '+12.3%',
    tokenPrice: 42.00,
    description: 'Monitoramento de ameaças em tempo real para PMEs',
    captureProgress: 0.55,
    logoColor: Color(0xFF18181B),
    logoIcon: Icons.security_outlined,
  ),
  CatalogStartup(
    name: 'Healthly',
    category: 'HEALTHTECH',
    stage: StartupStage.emExpansao,
    yieldPercentLabel: '+9.8%',
    tokenPrice: 8.75,
    description: 'Telemedicina e histórico clínico integrado',
    captureProgress: 0.92,
    logoColor: Color(0xFF14B8A6),
    logoIcon: Icons.favorite_outline,
  ),
];

/// MaterialApp mínimo com o mesmo tema roxo do [MyApp], para a tela usar cores corretas.
Widget _wrapCatalogScreen() {
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
    home: CatalogScreen(
      startupsStreamForTesting: Stream<List<CatalogStartup>>.value(
        kCatalogMockStartups,
      ),
    ),
  );
}

void main() {
  group('CatalogScreen', () {
    testWidgets('mostra título, hint da busca e as três startups mock', (tester) async {
      await tester.pumpWidget(_wrapCatalogScreen());
      await tester.pumpAndSettle();

      expect(find.text('Explorar'), findsOneWidget);
      expect(find.text('Buscar startups, setores...'), findsOneWidget);

      expect(find.text('GreenFlow'), findsOneWidget);
      expect(find.text('CyberMesh'), findsOneWidget);
      expect(find.text('Healthly'), findsOneWidget);
    });

    testWidgets('chip Novas deixa só startups no estágio Nova', (tester) async {
      await tester.pumpWidget(_wrapCatalogScreen());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Novas'));
      await tester.tap(find.text('Novas'));
      await tester.pumpAndSettle();

      expect(find.text('GreenFlow'), findsOneWidget);
      expect(find.text('CyberMesh'), findsNothing);
      expect(find.text('Healthly'), findsNothing);
    });

    testWidgets('busca por texto filtra nome e categoria', (tester) async {
      await tester.pumpWidget(_wrapCatalogScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Cyber');
      await tester.pumpAndSettle();

      expect(find.text('CyberMesh'), findsOneWidget);
      expect(find.text('GreenFlow'), findsNothing);
    });

    testWidgets('busca sem resultados mostra mensagem amigável', (tester) async {
      await tester.pumpWidget(_wrapCatalogScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyz123nada');
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma startup encontrada.'), findsOneWidget);
    });

    testWidgets('preço do token aparece formatado em reais', (tester) async {
      await tester.pumpWidget(_wrapCatalogScreen());
      await tester.pumpAndSettle();

      expect(find.text('R\$ 15,30'), findsOneWidget);
    });
  });
}
