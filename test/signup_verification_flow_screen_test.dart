// Testes TDD para SignupVerificationFlowScreen.
// Sem Firebase inicializado, sendCode() falha imediatamente; a tela mostra o
// estado de erro (_sendFailed = true) com botão de retry e opção de sair.
// O estado inicial de carregamento é transiente demais para ser testado de forma
// confiável sem controle da temporização do Future.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/auth/screens/signup_verification_flow_screen.dart';

Widget _buildScreen({String email = 'teste@example.com'}) {
  return MaterialApp(
    home: SignupVerificationFlowScreen(userEmail: email),
  );
}

void main() {
  group('SignupVerificationFlowScreen — estado de erro (sem Firebase)', () {
    testWidgets(
        'Após falha (Firebase não inicializado), exibe mensagem de erro', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Não foi possível enviar o código'),
        findsOneWidget,
      );
    });

    testWidgets('Exibe botão para tentar enviar código novamente', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tentar enviar código novamente'), findsOneWidget);
    });

    testWidgets('Exibe botão "Sair e voltar ao login"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sair e voltar ao login'), findsOneWidget);
    });
  });

  group('SignupVerificationFlowScreen — parâmetro de e-mail', () {
    testWidgets('Não lança exceção com e-mail vazio', (tester) async {
      await tester.pumpWidget(_buildScreen(email: ''));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Apenas verifica que a tela renderizou sem crash.
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Não lança exceção com e-mail válido', (tester) async {
      await tester.pumpWidget(_buildScreen(email: 'user@example.com'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
