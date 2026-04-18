// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Testes de widget: fluxo principal (login) e tela de dashboard isolada.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/main.dart';
import 'package:pi_iii/dashboard/screens/dashboard_screen.dart';

void main() {
  testWidgets('Login screen monta título do cartão e ação Entrar', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets(
      'Login válido abre 2FA e, com código 123456, vai ao dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final loginFields = find.byType(TextField);
    await tester.enterText(loginFields.at(0), 'user@test.com');
    await tester.enterText(loginFields.at(1), 'senha123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Verificação de duas etapas'), findsOneWidget);

    final otpFields = find.byType(TextField);
    expect(otpFields, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(otpFields.at(i), '123456'[i]);
    }
    await tester.tap(find.text('Validar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Verificação concluída!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('BOM DIA, RICARDO'), findsOneWidget);
  });

  testWidgets('Dashboard monta conteúdo principal', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(),
      ),
    );

    expect(find.text('BOM DIA, RICARDO'), findsOneWidget);
    expect(find.text('Seu Patrimônio'), findsOneWidget);
    expect(find.text('Minhas Startups'), findsOneWidget);
  });
}
