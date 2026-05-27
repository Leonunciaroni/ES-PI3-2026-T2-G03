// Testes TDD para BalcaoTransacaoDetalheScreen.
// Widget puro (StatelessWidget) — sem dependências de Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/balcao/models/balcao_operacao_tipo.dart';
import 'package:mescla_invest/balcao/models/balcao_transacao.dart';
import 'package:mescla_invest/balcao/screens/balcao_transacao_detalhe_screen.dart';

final _kDetalhCompra = BalcaoTransacaoDetalhe(
  operacao: BalcaoOperacaoTipo.compra,
  nomeToken: 'GFLO',
  quantidadeTokens: 5,
  valorReais: 76.50,
  dataHora: DateTime(2026, 4, 20, 14, 30),
  status: 'Concluída',
);

final _kDetalhVenda = BalcaoTransacaoDetalhe(
  operacao: BalcaoOperacaoTipo.venda,
  nomeToken: 'WHOP',
  quantidadeTokens: 2,
  valorReais: 38.75,
  dataHora: DateTime(2026, 5, 1, 10, 0),
  status: 'Concluída',
);

Widget _buildScreen(BalcaoTransacaoDetalhe detalhe) {
  return MaterialApp(
    home: BalcaoTransacaoDetalheScreen(detalhe: detalhe),
  );
}

void main() {
  group('BalcaoTransacaoDetalheScreen — compra', () {
    testWidgets('Exibe título do AppBar "Detalhe da transação"',
        (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhCompra));
      await tester.pumpAndSettle();

      expect(find.text('Detalhe da transação'), findsOneWidget);
    });

    testWidgets('Exibe "Compra concluída" para operação de compra',
        (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhCompra));
      await tester.pumpAndSettle();

      expect(find.text('Compra concluída'), findsOneWidget);
    });

    testWidgets('Exibe nome do token', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhCompra));
      await tester.pumpAndSettle();

      expect(find.text('Token GFLO'), findsOneWidget);
    });

    testWidgets('Exibe quantidade de tokens formatada', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhCompra));
      await tester.pumpAndSettle();

      expect(find.textContaining('5'), findsWidgets);
      expect(find.textContaining('tokens'), findsWidgets);
    });

    testWidgets('Exibe status da transação', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhCompra));
      await tester.pumpAndSettle();

      expect(find.text('Concluída'), findsWidgets);
    });

    testWidgets('Exibe botão "Voltar ao balcão"', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhCompra));
      await tester.pumpAndSettle();

      expect(find.text('Voltar ao balcão'), findsOneWidget);
    });

    testWidgets('Exibe card "Informações"', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhCompra));
      await tester.pumpAndSettle();

      expect(find.text('Informações'), findsOneWidget);
    });

    testWidgets('Exibe data e hora formatados em pt-BR', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhCompra));
      await tester.pumpAndSettle();

      // 20/04/2026 às 14:30
      expect(find.textContaining('20/04/2026'), findsOneWidget);
    });
  });

  group('BalcaoTransacaoDetalheScreen — venda', () {
    testWidgets('Exibe "Venda concluída" para operação de venda',
        (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhVenda));
      await tester.pumpAndSettle();

      expect(find.text('Venda concluída'), findsOneWidget);
    });

    testWidgets('Exibe nome do token WHOP', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalhVenda));
      await tester.pumpAndSettle();

      expect(find.text('Token WHOP'), findsOneWidget);
    });
  });
}
