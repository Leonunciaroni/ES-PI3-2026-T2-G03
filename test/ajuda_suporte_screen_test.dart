// Testes TDD para AjudaSuporteScreen.
// Widget puro — sem dependências Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/perfil/screens/ajuda_suporte_screen.dart';

Widget _buildScreen() {
  return const MaterialApp(home: AjudaSuporteScreen());
}

void main() {
  group('AjudaSuporteScreen — UI', () {
    testWidgets('Exibe título "Ajuda e Suporte"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Ajuda e Suporte'), findsOneWidget);
    });

    testWidgets('Exibe seção de dúvidas frequentes', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Dúvidas frequentes'), findsOneWidget);
    });

    testWidgets('Exibe pergunta sobre adicionar saldo', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('Como adiciono saldo à minha carteira?'),
        findsOneWidget,
      );
    });

    testWidgets('Exibe pergunta sobre compra/venda de tokens', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Onde compro ou vendo tokens?'), findsOneWidget);
    });

    testWidgets('Exibe pergunta sobre tempo de saque', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('Quanto tempo demora um saque simulado?'),
        findsOneWidget,
      );
    });

    testWidgets('Exibe pergunta sobre verificação em duas etapas',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('Como ativo a verificação em duas etapas?'),
        findsOneWidget,
      );
    });

    testWidgets('Exibe seção "Fale conosco"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Fale conosco'), findsOneWidget);
    });

    testWidgets('Exibe e-mail de suporte', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('suporte_exemplo@mesclainvest.app'),
        findsOneWidget,
      );
    });

    testWidgets('Exibe horário de atendimento', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Segunda a sexta'), findsOneWidget);
    });
  });
}
