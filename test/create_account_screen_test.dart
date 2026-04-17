import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_iii/screens/create_account_screen.dart';

Future<void> _mockAssets() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = 'flutter/assets';
  ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    channel,
    (message) async => ByteData(0),
  );
}

void main() {
  setUpAll(_mockAssets);

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

    await tester.tap(find.text('Criar Conta →'));
    await tester.pump();

    expect(
      find.text(
        'Aceite os Termos de Uso e a Política de Privacidade para continuar.',
      ),
      findsOneWidget,
    );
  });
}
