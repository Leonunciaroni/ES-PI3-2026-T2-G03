// Testes TDD para SacarSenhaScreen.
// Com debitarSaldoReal: false, não há chamadas Firebase nem biometria automática.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/carteira/models/pix_chave_ui.dart';
import 'package:mescla_invest/carteira/screens/sacar_senha_screen.dart';

final _kChave = PixChaveUi(
  id: 'k1',
  tipoLabel: 'E-mail',
  valor: 'user@test.com',
);

Widget _buildScreen({double valor = 150.0}) {
  return MaterialApp(
    home: SacarSenhaScreen(
      valorReais: valor,
      chavePix: _kChave,
      debitarSaldoReal: false, // Evita chamadas Firebase e biometria.
    ),
  );
}

void main() {
  group('SacarSenhaScreen — UI', () {
    testWidgets('Exibe campo de senha', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Exibe o valor do saque', (tester) async {
      await tester.pumpWidget(_buildScreen(valor: 150.0));
      await tester.pumpAndSettle();

      expect(find.textContaining('150'), findsWidgets);
    });

    testWidgets('Exibe título "Confirmar saque" no AppBar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Confirmar saque'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Exibe destino do saque mascarado', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // O valor da chave é mascarado; a linha começa com "Destino:"
      expect(find.textContaining('Destino:'), findsOneWidget);
    });

    testWidgets('Campo de senha inicia obscurecido', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('Botão de olho alterna visibilidade da senha', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final eyeIcon = find.byIcon(Icons.visibility_outlined);
      expect(eyeIcon, findsOneWidget);

      await tester.tap(eyeIcon);
      await tester.pump();

      final eyeOffIcon = find.byIcon(Icons.visibility_off_outlined);
      expect(eyeOffIcon, findsOneWidget);
    });
  });

  group('SacarSenhaScreen — validação', () {
    testWidgets('Confirmar com campo vazio mostra erro inline', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // O botão "Confirmar saque" pode estar abaixo do viewport; rola para ele.
      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      // Erro exibido inline (não SnackBar).
      expect(find.text('Informe sua senha.'), findsOneWidget);
    });
  });

  group('SacarSenhaScreen — modo convidado (sem débito real)', () {
    testWidgets('Com debitarSaldoReal: false, não exibe botão biométrico',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // Sem biometria ativa, não aparece o ícone de fingerprint
      expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);
    });
  });
}
