// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Testes de widget desta branch: arranque na Carteira (demo).

import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/main.dart';

void main() {
  testWidgets('App arranca na Carteira (demo desta branch)', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Carteira'), findsOneWidget);
  });
}
