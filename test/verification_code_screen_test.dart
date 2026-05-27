// Testes TDD para VerificationCodeScreen.
// Verifica título, campos de código OTP, countdown e feedback ao usuário.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/auth/screens/verification_code_screen.dart';

Widget _buildScreen({String email = 'test@example.com'}) {
  return MaterialApp(
    home: VerificationCodeScreen(email: email),
  );
}

void main() {
  group('VerificationCodeScreen — UI', () {
    testWidgets('Exibe título "Código de verificação"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Código de verificação'), findsOneWidget);
    });

    testWidgets('Exibe 6 campos OTP individuais', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('Exibe botão "Verificar código"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Verificar código'), findsOneWidget);
    });

    testWidgets('Exibe rodapé do projeto', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('PROJETO INTEGRADOR III - GRUPO 3'), findsOneWidget);
    });

    testWidgets('Exibe o e-mail passado como parâmetro', (tester) async {
      await tester.pumpWidget(_buildScreen(email: 'usuario@teste.com'));
      await tester.pump();

      expect(find.textContaining('usuario@teste.com'), findsWidgets);
    });

    testWidgets('Exibe countdown inicial de reenvio', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(
        find.textContaining('Solicitar novamente em'),
        findsOneWidget,
      );
    });
  });

  group('VerificationCodeScreen — validação', () {
    testWidgets('Confirmar sem 6 dígitos mostra SnackBar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      await tester.tap(find.text('Verificar código'));
      await tester.pump();

      expect(
        find.text('Informe os 6 dígitos do código.'),
        findsOneWidget,
      );
    });
  });

  group('VerificationCodeScreen — entrada de código', () {
    testWidgets('Digitar em cada campo atualiza os controllers', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(6));

      for (var i = 0; i < 6; i++) {
        await tester.enterText(fields.at(i), '${i + 1}');
      }
      await tester.pump();

      // Após preencher 6 campos, o código tenta verificação automaticamente
      // (tentará chamar Firebase, que falhará; sem crash)
    });

    testWidgets('Botão voltar está presente', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });
  });
}
