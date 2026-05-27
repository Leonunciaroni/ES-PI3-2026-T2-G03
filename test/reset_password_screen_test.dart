// Testes TDD para ResetPasswordScreen.
// Verifica título, campos de senha, checklist de validação e feedback ao usuário.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/auth/screens/reset_password_screen.dart';

Widget _buildScreen({String sessionToken = 'fake-token'}) {
  return MaterialApp(
    home: ResetPasswordScreen(sessionToken: sessionToken),
  );
}

void main() {
  group('ResetPasswordScreen — UI', () {
    testWidgets('Exibe título "Nova senha"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Nova senha'), findsOneWidget);
    });

    testWidgets('Exibe subtítulo explicativo', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Digite a nova senha'),
        findsOneWidget,
      );
    });

    testWidgets('Exibe dois campos de senha', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('Exibe label "SENHA SEGURA *"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('SENHA SEGURA'), findsOneWidget);
    });

    testWidgets('Exibe label "INSERIR NOVAMENTE*"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('INSERIR NOVAMENTE'), findsOneWidget);
    });

    testWidgets('Exibe botão "Confirmar"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Confirmar'), findsOneWidget);
    });

    testWidgets('Exibe rodapé do projeto', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('PROJETO INTEGRADOR III - GRUPO 3'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen — checklist de validação', () {
    testWidgets('Checklist aparece com todos os requisitos', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('DEVE CONTER 8 CARACTERES'), findsOneWidget);
      expect(find.text('PELO MENOS UMA LETRA MAIÚSCULA'), findsOneWidget);
      expect(find.text('DEVE CONTER NÚMEROS'), findsOneWidget);
      expect(find.text('PELO MENOS UM CARACTERE ESPECIAL'), findsOneWidget);
    });

    testWidgets('Ao digitar senha válida, checklist fica satisfeita',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'Senha@123');
      await tester.pump();

      // Os ícones de check devem aparecer (check_circle_outline_rounded)
      expect(
        find.byIcon(Icons.check_circle_outline_rounded),
        findsNWidgets(4),
      );
    });
  });

  group('ResetPasswordScreen — validação ao confirmar', () {
    testWidgets('Campos vazios mostram SnackBar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // O botão pode estar abaixo do viewport; rola para ele antes de tocar.
      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      expect(find.text('Preencha ambos os campos de senha.'), findsOneWidget);
    });

    testWidgets('Senhas diferentes mostram SnackBar de não coincidem',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Senha@123');
      await tester.enterText(fields.at(1), 'Outra@456');
      await tester.pump();

      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      expect(find.text('As senhas não coincidem.'), findsOneWidget);
    });

    testWidgets('Senha sem 8 caracteres mostra SnackBar correto',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ab@1');
      await tester.enterText(fields.at(1), 'Ab@1');
      await tester.pump();

      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      expect(
        find.text('A senha deve ter pelo menos 8 caracteres.'),
        findsOneWidget,
      );
    });

    testWidgets('Senha sem maiúscula mostra SnackBar correto', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'senha@123');
      await tester.enterText(fields.at(1), 'senha@123');
      await tester.pump();

      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      expect(
        find.text('A senha deve conter pelo menos uma letra maiúscula.'),
        findsOneWidget,
      );
    });

    testWidgets('Senha sem número mostra SnackBar correto', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Senha@abc');
      await tester.enterText(fields.at(1), 'Senha@abc');
      await tester.pump();

      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      expect(
        find.text('A senha deve conter pelo menos um número.'),
        findsOneWidget,
      );
    });

    testWidgets('Senha sem caractere especial mostra SnackBar correto',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Senha1234');
      await tester.enterText(fields.at(1), 'Senha1234');
      await tester.pump();

      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      expect(
        find.text('A senha deve conter pelo menos um caractere especial.'),
        findsOneWidget,
      );
    });
  });

  group('ResetPasswordScreen — botão voltar', () {
    testWidgets('Botão de voltar está presente', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });
  });
}
