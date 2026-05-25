// Testes TDD para SaqueComprovanteScreen.
// Widget puro (StatelessWidget) — sem dependências de Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/carteira/models/pix_chave_ui.dart';
import 'package:mescla_invest/carteira/screens/saque_comprovante_screen.dart';

final _kChavePix = PixChaveUi(
  id: 'chave-01',
  tipoLabel: 'E-mail',
  valor: 'usuario@example.com',
);

final _kDataHora = DateTime(2026, 4, 15, 10, 30);

Widget _buildScreen({
  double valor = 250.00,
  PixChaveUi? chave,
  DateTime? dataHora,
}) {
  return MaterialApp(
    home: SaqueComprovanteScreen(
      valorReais: valor,
      chavePix: chave ?? _kChavePix,
      dataHora: dataHora ?? _kDataHora,
    ),
  );
}

void main() {
  group('SaqueComprovanteScreen — UI', () {
    testWidgets('Exibe título "Comprovante" no AppBar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Comprovante'), findsOneWidget);
    });

    testWidgets('Exibe "Saque concluído"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Saque concluído'), findsOneWidget);
    });

    testWidgets('Exibe tipo de chave PIX no subtítulo', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('PIX'), findsWidgets);
      expect(find.textContaining('E-mail'), findsWidgets);
    });

    testWidgets('Exibe o valor em reais formatado', (tester) async {
      await tester.pumpWidget(_buildScreen(valor: 250.00));
      await tester.pumpAndSettle();

      expect(find.textContaining('250'), findsWidgets);
    });

    testWidgets('Exibe o card "Informações"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Informações'), findsOneWidget);
    });

    testWidgets('Exibe data e hora no card de informações', (tester) async {
      await tester.pumpWidget(_buildScreen(dataHora: DateTime(2026, 4, 15, 10, 30)));
      await tester.pumpAndSettle();

      expect(find.textContaining('15/04/2026'), findsOneWidget);
    });

    testWidgets('Exibe status "Concluída (demonstração)"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Concluída (demonstração)'), findsOneWidget);
    });

    testWidgets('Exibe botão de voltar à carteira', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('carteira'), findsWidgets);
    });

    testWidgets('Exibe chave PIX mascarada', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // O valor é mascarado — não aparece o email completo, mas aparece "Chave:"
      expect(find.textContaining('Chave:'), findsOneWidget);
    });
  });

  group('SaqueComprovanteScreen — diferentes chaves PIX', () {
    testWidgets('Funciona com chave CPF', (tester) async {
      final chaveCpf = PixChaveUi(
        id: 'cpf-01',
        tipoLabel: 'CPF',
        valor: '12345678901',
      );
      await tester.pumpWidget(_buildScreen(chave: chaveCpf));
      await tester.pumpAndSettle();

      expect(find.textContaining('CPF'), findsWidgets);
    });

    testWidgets('Funciona com valor de saque zero', (tester) async {
      await tester.pumpWidget(_buildScreen(valor: 0.0));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
