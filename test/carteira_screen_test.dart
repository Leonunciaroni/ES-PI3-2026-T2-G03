import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/carteira/screens/carteira_screen.dart';

void main() {
  testWidgets('CarteiraScreen mostra título e saldo total', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CarteiraScreen(wrapWithSafeArea: false),
        ),
      ),
    );

    expect(find.text('Carteira'), findsOneWidget);
    expect(find.textContaining('SALDO TOTAL INVESTIDO'), findsOneWidget);
    expect(find.textContaining('12.450'), findsOneWidget);
  });

  testWidgets('+ Adicionar Fundos abre ecrã Adicionar fundos', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CarteiraScreen(wrapWithSafeArea: false),
        ),
      ),
    );

    final addBtn = find.text('+ Adicionar Fundos').first;
    await tester.scrollUntilVisible(
      addBtn,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.text('Quanto deseja investir?'), findsOneWidget);
  });
}
