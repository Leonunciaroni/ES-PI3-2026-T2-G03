import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/main.dart';

void main() {
  testWidgets('App arranca na Carteira (demo desta branch)', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Carteira'), findsOneWidget);
  });
}
