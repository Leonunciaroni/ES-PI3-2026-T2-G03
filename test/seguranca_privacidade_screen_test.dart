// Testes TDD para SegurancaPrivacidadeScreen.
// Sem Firebase inicializado, _currentUidOrNull() retorna null (guarded),
// e a tela exibe a mensagem de "Inicie sessão" no lugar dos controles de segurança.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/perfil/screens/seguranca_privacidade_screen.dart';

Widget _buildScreen() {
  return const MaterialApp(home: SegurancaPrivacidadeScreen());
}

void main() {
  group('SegurancaPrivacidadeScreen — sem sessão Firebase', () {
    testWidgets('Exibe título "Segurança e Privacidade"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Segurança e Privacidade'), findsOneWidget);
    });

    testWidgets(
        'Exibe mensagem para iniciar sessão quando Firebase não está ativo',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Inicie sessão'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Não exibe controles de 2FA quando usuário não está autenticado',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('Verificação em duas etapas (2FA)'),
        findsNothing,
      );
    });

    testWidgets('Não exibe SwitchListTile de 2FA sem sessão', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('Renderiza sem crash', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
