// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/main.dart';

void main() {
  testWidgets('Login screen monta e mostra marca Mescla Invest', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Mescla Invest'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
