// Testes TDD para BalcaoQuantidadeTokensScreen.
// Firebase é guardado com try/catch na classe; a tela renderiza sem crash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/balcao/models/balcao_operacao_tipo.dart';
import 'package:mescla_invest/balcao/screens/balcao_quantidade_tokens_screen.dart';
import 'package:mescla_invest/catalog/models/catalog_startup.dart';

const _kStartup = CatalogStartup(
  name: 'GreenFlow',
  category: 'AGROTECH',
  stage: StartupStage.nova,
  yieldPercentLabel: '+18.5%',
  tokenPrice: 15.30,
  description: 'Startup de agro',
  captureProgress: 0.6,
  logoColor: Color(0xFF22C55E),
  logoIcon: Icons.eco_outlined,
  firestoreId: null,
);

Widget _buildCompra() {
  return MaterialApp(
    home: BalcaoQuantidadeTokensScreen(
      startup: _kStartup,
      operacao: BalcaoOperacaoTipo.compra,
      cotacaoOficialBrl: 15.30,
    ),
  );
}

Widget _buildVenda() {
  return MaterialApp(
    home: BalcaoQuantidadeTokensScreen(
      startup: _kStartup,
      operacao: BalcaoOperacaoTipo.venda,
      cotacaoOficialBrl: 15.30,
    ),
  );
}

void main() {
  group('BalcaoQuantidadeTokensScreen — compra', () {
    testWidgets('Renderiza sem crash', (tester) async {
      await tester.pumpWidget(_buildCompra());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Exibe título do AppBar para compra', (tester) async {
      await tester.pumpWidget(_buildCompra());
      await tester.pumpAndSettle();

      expect(find.textContaining('mercado'), findsWidgets);
    });

    testWidgets('Exibe campo de valor em reais', (tester) async {
      await tester.pumpWidget(_buildCompra());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('Exibe nome da startup no conteúdo', (tester) async {
      await tester.pumpWidget(_buildCompra());
      await tester.pumpAndSettle();

      expect(find.textContaining('GreenFlow'), findsWidgets);
    });
  });

  group('BalcaoQuantidadeTokensScreen — venda', () {
    testWidgets('Renderiza tela de venda sem crash', (tester) async {
      await tester.pumpWidget(_buildVenda());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Exibe título AppBar para venda', (tester) async {
      await tester.pumpWidget(_buildVenda());
      await tester.pumpAndSettle();

      expect(find.textContaining('enda'), findsWidgets);
    });

    testWidgets('Exibe campo de quantidade de tokens na venda', (tester) async {
      await tester.pumpWidget(_buildVenda());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
      expect(find.textContaining('Quantidade de tokens'), findsOneWidget);
    });
  });
}
