// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Testes de widget da [CarteiraScreen]. [usarFirebaseParaSessao] fica `false`
// para não depender de plugins nativos do Firebase no VM do `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/carteira/screens/carteira_screen.dart';

void main() {
  testWidgets('CarteiraScreen mostra título e saldo total', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CarteiraScreen(
            wrapWithSafeArea: false,
            usarFirebaseParaSessao: false,
          ),
        ),
      ),
    );

    expect(find.text('Carteira'), findsOneWidget);
    expect(find.textContaining('SALDO TOTAL INVESTIDO'), findsOneWidget);
    expect(find.textContaining('12.450'), findsOneWidget);
  });

  testWidgets('+ Adicionar Saldo abre fluxo Adicionar fundos', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CarteiraScreen(
            wrapWithSafeArea: false,
            usarFirebaseParaSessao: false,
          ),
        ),
      ),
    );

    final addBtn = find.text('+ Adicionar Saldo');
    await tester.ensureVisible(addBtn);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.text('Quanto deseja investir?'), findsOneWidget);
  });

  testWidgets('Sacar abre ecrã do fluxo de saque', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CarteiraScreen(
            wrapWithSafeArea: false,
            usarFirebaseParaSessao: false,
          ),
        ),
      ),
    );

    final sacarBtn = find.text('Sacar');
    await tester.ensureVisible(sacarBtn);
    await tester.tap(sacarBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Saldo disponível para saque'), findsOneWidget);
  });

  testWidgets('Minhas Chaves PIX aparece abaixo do gráfico', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CarteiraScreen(
            wrapWithSafeArea: false,
            usarFirebaseParaSessao: false,
          ),
        ),
      ),
    );

    final scrollCarteira = find.descendant(
      of: find.byType(CarteiraScreen),
      matching: find.byType(Scrollable),
    );
    await tester.dragUntilVisible(
      find.text('Minhas Chaves PIX'),
      scrollCarteira.first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(find.text('Minhas Chaves PIX'), findsOneWidget);
  });
}
