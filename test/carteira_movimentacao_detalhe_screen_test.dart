// Testes TDD para CarteiraMovimentacaoDetalheScreen.
// Widget puro (StatelessWidget) — sem dependências de Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/carteira/models/carteira_movimentacao_detalhe.dart';
import 'package:mescla_invest/carteira/screens/carteira_movimentacao_detalhe_screen.dart';

final _kDetalheSaque = CarteiraMovimentacaoDetalhe(
  tituloConclusao: 'Saque concluído',
  subtitulo: 'PIX · E-mail',
  valorReaisExibicao: 'R\$ 100,00',
  dataHora: DateTime(2026, 3, 10, 9, 0),
  linhaRodapeOpcional: 'Chave: usuario@…',
  status: 'Concluída (demonstração)',
);

final _kDetalheCompra = CarteiraMovimentacaoDetalhe(
  tituloConclusao: 'Compra concluída',
  subtitulo: 'Token GFLO',
  valorReaisExibicao: 'R\$ 76,50',
  dataHora: DateTime(2026, 4, 1, 15, 0),
  linhaRodapeOpcional: 'Quantidade: 5 tokens',
  status: 'Concluída (demonstração)',
);

final _kDetalheCredito = CarteiraMovimentacaoDetalhe(
  tituloConclusao: 'Crédito concluído',
  subtitulo: 'PIX · Crédito simulado',
  valorReaisExibicao: 'R\$ 500,00',
  dataHora: DateTime(2026, 2, 20, 11, 30),
);

Widget _buildScreen(CarteiraMovimentacaoDetalhe detalhe) {
  return MaterialApp(
    home: CarteiraMovimentacaoDetalheScreen(detalhe: detalhe),
  );
}

void main() {
  group('CarteiraMovimentacaoDetalheScreen — saque', () {
    testWidgets('Exibe título "Comprovante" no AppBar', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheSaque));
      await tester.pumpAndSettle();

      expect(find.text('Comprovante'), findsOneWidget);
    });

    testWidgets('Exibe título de conclusão do saque', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheSaque));
      await tester.pumpAndSettle();

      expect(find.text('Saque concluído'), findsOneWidget);
    });

    testWidgets('Exibe subtítulo "PIX · E-mail"', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheSaque));
      await tester.pumpAndSettle();

      expect(find.text('PIX · E-mail'), findsOneWidget);
    });

    testWidgets('Exibe valor em reais', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheSaque));
      await tester.pumpAndSettle();

      expect(find.text('R\$ 100,00'), findsOneWidget);
    });

    testWidgets('Exibe linha rodapé com chave', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheSaque));
      await tester.pumpAndSettle();

      expect(find.text('Chave: usuario@…'), findsOneWidget);
    });

    testWidgets('Exibe card "Informações"', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheSaque));
      await tester.pumpAndSettle();

      expect(find.text('Informações'), findsOneWidget);
    });

    testWidgets('Exibe data e hora formatada', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheSaque));
      await tester.pumpAndSettle();

      expect(find.textContaining('10/03/2026'), findsOneWidget);
    });

    testWidgets('Exibe botão de voltar', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheSaque));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });
  });

  group('CarteiraMovimentacaoDetalheScreen — compra de token', () {
    testWidgets('Exibe "Compra concluída"', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheCompra));
      await tester.pumpAndSettle();

      expect(find.text('Compra concluída'), findsOneWidget);
    });

    testWidgets('Exibe subtítulo do token', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheCompra));
      await tester.pumpAndSettle();

      expect(find.text('Token GFLO'), findsOneWidget);
    });

    testWidgets('Exibe linha de quantidade de tokens', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheCompra));
      await tester.pumpAndSettle();

      expect(find.text('Quantidade: 5 tokens'), findsOneWidget);
    });
  });

  group('CarteiraMovimentacaoDetalheScreen — crédito (sem rodapé opcional)',
      () {
    testWidgets('Renderiza sem rodapé opcional sem crash', (tester) async {
      await tester.pumpWidget(_buildScreen(_kDetalheCredito));
      await tester.pumpAndSettle();

      expect(find.text('Crédito concluído'), findsOneWidget);
    });
  });
}
