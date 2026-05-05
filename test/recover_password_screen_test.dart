import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/auth/screens/recover_password_screen.dart';

void main() {
  testWidgets('RecoverPasswordScreen mostra título e campo de e-mail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RecoverPasswordScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recuperar senha'), findsOneWidget);
    expect(find.text('Enviar instruções'), findsOneWidget);
  });
}
