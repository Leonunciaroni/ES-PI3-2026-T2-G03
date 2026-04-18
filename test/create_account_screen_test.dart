import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_iii/auth/screens/create_account_screen.dart';

void main() {
  Widget buildScreen() {
    return const MaterialApp(home: CreateAccountScreen());
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

    await tester.ensureVisible(checkboxFinder);
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

    final criarConta = find.text('Criar Conta →');
    await tester.ensureVisible(criarConta);
    await tester.tap(criarConta);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Aceite os Termos de Uso e a Política de Privacidade para continuar.',
      ),
      findsOneWidget,
    );
  });
}
