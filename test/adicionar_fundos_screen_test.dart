import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/carteira/screens/adicionar_fundos_screen.dart';

void main() {
  testWidgets('AdicionarFundosScreen mostra título e CTA', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdicionarFundosScreen(),
      ),
    );

    expect(find.text('Quanto deseja investir?'), findsOneWidget);
    expect(find.text('Investir agora'), findsOneWidget);
    expect(find.textContaining('1 token ='), findsNothing);
  });

  testWidgets('valor preenchido ativa Investir agora', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdicionarFundosScreen(),
      ),
    );

    final investirFinder = find.widgetWithText(FilledButton, 'Investir agora');
    expect(tester.widget<FilledButton>(investirFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '1000,00');
    await tester.pump();

    expect(tester.widget<FilledButton>(investirFinder).onPressed, isNotNull);
  });

  testWidgets('Confirmar transação mostra só o valor em reais', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdicionarFundosScreen(),
      ),
    );

    await tester.enterText(find.byType(TextField), '100,00');
    await tester.pump();

    await tester.tap(find.text('Investir agora'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar transação'), findsOneWidget);
    expect(
      find.textContaining('Confirma o investimento de R\$ 100,00?'),
      findsOneWidget,
    );
    expect(find.textContaining('token'), findsNothing);
  });

  test('parseValorReaisInput interpreta milhar BR', () {
    expect(parseValorReaisInput('1.000,50'), 1000.5);
    expect(parseValorReaisInput('1000'), 1000);
    expect(parseValorReaisInput('R\$ 500,25'), 500.25);
    expect(parseValorReaisInput(''), null);
  });
}
