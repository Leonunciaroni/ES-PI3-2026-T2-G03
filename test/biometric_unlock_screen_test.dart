// Testes TDD para BiometricUnlockScreen.
// O serviço biométrico retorna [BiometricAuthOutcome.error] em testes (plugin local_auth
// indisponível no VM de teste), capturado silenciosamente.
// Não usa pumpAndSettle para evitar timeout de animações contínuas (logo, etc.).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/auth/screens/biometric_unlock_screen.dart';

Widget _buildScreen() {
  return const MaterialApp(home: BiometricUnlockScreen());
}

/// Pumps suficientes para que a operação biométrica assíncrona complete.
Future<void> _pumpUntilSettled(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('BiometricUnlockScreen — UI inicial', () {
    testWidgets('Exibe título "Desbloqueio seguro"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Desbloqueio seguro'), findsOneWidget);
    });

    testWidgets('Exibe descrição de biometria', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.textContaining('biometria'), findsWidgets);
    });

    testWidgets('Exibe botão "Entrar com e-mail e senha"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Entrar com e-mail e senha'), findsOneWidget);
    });
  });

  group('BiometricUnlockScreen — após tentativa biométrica', () {
    testWidgets(
        'Após falha do plugin biométrico, exibe botão "Tentar de novo"',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _pumpUntilSettled(tester);

      // O botão muda de "Aguardando…" para "Tentar de novo"
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('Exibe mensagem de erro de biometria', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _pumpUntilSettled(tester);

      expect(
        find.textContaining('Não foi possível usar a biometria'),
        findsOneWidget,
      );
    });

    testWidgets('Botão "Entrar com e-mail e senha" está habilitado após falha',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _pumpUntilSettled(tester);

      final btn = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Entrar com e-mail e senha'),
          matching: find.byType(TextButton),
        ),
      );
      expect(btn.onPressed, isNotNull);
    });
  });
}
