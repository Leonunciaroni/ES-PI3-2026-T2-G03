// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Smoke test: arranque na tela de login e navegação para recuperação de senha.

import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/main.dart';

void main() {
  testWidgets('App arranca na tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('Login navega para recuperação de senha', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar senha'), findsOneWidget);
  });

  testWidgets('Recuperação sem e-mail válido mostra aviso', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enviar instruções'));
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
  });
}
