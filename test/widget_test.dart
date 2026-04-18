// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Smoke test: arranque na tela de login (fluxo principal integrado).

import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/main.dart';

void main() {
  testWidgets('App arranca na tela de login', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
  });
}
