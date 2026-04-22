import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_iii/screens/create_account_screen.dart';

void main() {
  Widget buildScreen() {
    return const MaterialApp(home: CreateAccountScreen());
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('Renderiza campo de telefone acima do CPF', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('TELEFONE CELULAR *'), findsOneWidget);
    expect(find.text('CPF *'), findsOneWidget);
    expect(find.text('Ex: (19) 99999-9999'), findsOneWidget);
  });

  testWidgets('Permite marcar aceite dos termos', (WidgetTester tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);

    Checkbox checkbox = tester.widget<Checkbox>(checkboxFinder);
    expect(checkbox.value, isFalse);

    await scrollTo(tester, checkboxFinder);
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    checkbox = tester.widget<Checkbox>(checkboxFinder);
    expect(checkbox.value, isTrue);
  });

  testWidgets('Mostra alerta ao criar conta sem aceitar termos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Usuário Teste');
    await tester.enterText(find.byType(TextField).at(1), 'teste@email.com');
    await tester.enterText(find.byType(TextField).at(2), '(19) 99999-9999');
    await tester.enterText(find.byType(TextField).at(3), '123.456.789-00');
    final createButton = find.text('Criar Conta →');
    await scrollTo(tester, createButton);
    await tester.tap(createButton);
    await tester.pump();

    expect(
      find.text(
        'Aceite os Termos de Uso e a Política de Privacidade para continuar.',
      ),
      findsOneWidget,
    );
  });
}
