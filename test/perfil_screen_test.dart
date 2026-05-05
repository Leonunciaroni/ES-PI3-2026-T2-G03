import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/perfil/screens/perfil_screen.dart';

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
    expect(find.text('Favoritos'), findsOneWidget);
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

    final seguranca = find.text('Segurança e Privacidade');
    await tester.ensureVisible(seguranca);
    await tester.pumpAndSettle();
    await tester.tap(seguranca);
    await tester.pumpAndSettle();

    // Sem sessão: não há interruptor 2FA; mensagem e recuperação de senha mantêm-se.
    expect(
      find.text(
        'Inicie sessão para ativar ou desativar a verificação em duas etapas.',
      ),
      findsOneWidget,
    );
    expect(find.text('Trocar senha por e-mail'), findsOneWidget);
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

    final sair = find.text('Sair da Conta');
    await tester.ensureVisible(sair);
    await tester.pumpAndSettle();
    await tester.tap(sair);
    await tester.pumpAndSettle();

    expect(find.text('Sair do aplicativo?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Sair do aplicativo?'), findsNothing);
    expect(find.text('Perfil'), findsOneWidget);
  });
}
