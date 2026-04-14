// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Testes de widget: fluxo principal (login) e tela de dashboard isolada.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/main.dart';
import 'package:pi_iii/screens/dashboard_screen.dart';

void main() {
  testWidgets('Login screen monta e mostra marca Mescla Invest', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Mescla Invest'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('Dashboard monta conteúdo principal', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(),
      ),
    );

    expect(find.text('BOM DIA, RICARDO'), findsOneWidget);
    expect(find.text('Seu Patrimônio'), findsOneWidget);
    expect(find.text('Minhas Startups'), findsOneWidget);
  });
}
