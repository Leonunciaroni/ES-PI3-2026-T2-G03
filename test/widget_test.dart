// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/main.dart';

void main() {
  testWidgets('Login screen monta título e botão de entrada', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
