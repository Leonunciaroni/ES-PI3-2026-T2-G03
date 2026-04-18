import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/carteira/screens/adicionar_fundos_screen.dart';

void main() {
  testWidgets('AdicionarFundosScreen mostra título e preço do token', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdicionarFundosScreen(),
      ),
    );

    expect(find.text('Quanto deseja investir?'), findsOneWidget);
    expect(find.textContaining('1 token ='), findsOneWidget);
    expect(find.textContaining('15,30'), findsOneWidget);
  });

  testWidgets('valor 1000,00 mostra quantidade de tokens', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdicionarFundosScreen(),
      ),
    );

    await tester.enterText(find.byType(TextField), '1000,00');
    await tester.pump();

    // 1000 / 15.30 ≈ 65,36 tokens (vírgula na UI)
    expect(find.textContaining('65'), findsWidgets);
    expect(find.textContaining('token'), findsWidgets);
  });

  test('parseValorReaisInput interpreta milhar BR', () {
    expect(parseValorReaisInput('1.000,50'), 1000.5);
    expect(parseValorReaisInput('1000'), 1000);
    expect(parseValorReaisInput('R\$ 500,25'), 500.25);
    expect(parseValorReaisInput(''), null);
  });

  testWidgets('após 21 s o botão Investir fica desativado', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdicionarFundosScreen(),
      ),
    );

    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();

    final investirFinder = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(investirFinder).onPressed, isNotNull);

    await tester.pump(const Duration(seconds: 21));

    expect(tester.widget<FilledButton>(investirFinder).onPressed, isNull);
  });
}
