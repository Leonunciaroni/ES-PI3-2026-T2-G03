import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/perfil/screens/perfil_screen.dart';

void main() {
  testWidgets('Perfil mostra título, CONTA e Sair da Conta', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PerfilScreen(wrapWithSafeArea: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('CONTA'), findsOneWidget);
    expect(find.text('SESSÃO'), findsOneWidget);
    expect(find.text('Sair da Conta'), findsOneWidget);
    expect(find.text('Segurança e Privacidade'), findsOneWidget);
  });

  testWidgets('Toque em Segurança abre subpágina', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PerfilScreen(wrapWithSafeArea: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Segurança e Privacidade'));
    await tester.pumpAndSettle();

    expect(find.text('Verificação em duas etapas (2FA)'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Recuperar senha por e-mail'), findsOneWidget);
  });

  testWidgets('Sair da Conta abre diálogo de confirmação', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PerfilScreen(wrapWithSafeArea: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sair da Conta'));
    await tester.pumpAndSettle();

    expect(find.text('Sair do aplicativo?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Sair do aplicativo?'), findsNothing);
    expect(find.text('Perfil'), findsOneWidget);
  });
}
