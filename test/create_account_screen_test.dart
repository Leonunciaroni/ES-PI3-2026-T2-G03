import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_iii/auth/screens/create_account_screen.dart';

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
    // CPF válido (dígitos verificadores corretos) para passar na validação até os termos.
    await tester.enterText(find.byType(TextField).at(3), '529.982.247-25');
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

  testWidgets('Rejeita celular sem 9 após o DDD', (WidgetTester tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Usuário Teste');
    await tester.enterText(find.byType(TextField).at(1), 'teste@email.com');
    // Onze dígitos, mas o primeiro após o DDD não é 9 (não é celular atual).
    await tester.enterText(find.byType(TextField).at(2), '(11) 32345-6789');
    await tester.enterText(find.byType(TextField).at(3), '529.982.247-25');

    final createButton = find.text('Criar Conta →');
    await scrollTo(tester, createButton);
    await tester.tap(createButton);
    await tester.pump();

    expect(
      find.text(
        'Telefone celular inválido. Informe DDD + 9 dígitos, no formato '
        '(XX) 9XXXX-XXXX.',
      ),
      findsOneWidget,
    );
  });
}
