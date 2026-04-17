// Testes de widget focados na tela Explorar (catálogo).
//
// Correm com: flutter test test/catalog_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/screens/catalog_screen.dart';
import 'package:pi_iii/theme/app_colors.dart';

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
    home: const CatalogScreen(),
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

      // Garante que o chip está visível (lista horizontal).
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

      // GreenFlow: tokenPrice 15.30 → "R$ 15,30"
      expect(find.text('R\$ 15,30'), findsOneWidget);
    });

    testWidgets('toque no nome da startup abre detalhes com CTA e captação', (tester) async {
      await tester.pumpWidget(_wrapCatalogScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('GreenFlow'));
      await tester.pumpAndSettle();

      expect(find.text('Investir Agora'), findsOneWidget);
      expect(find.text('CAPTAÇÃO ATUAL'), findsOneWidget);
      expect(find.text('Evolução de Valuation'), findsOneWidget);
    });
  });
}
