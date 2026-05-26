// Testes TDD para StartupQaFullScreen.
// Widget puro — sem dependências Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/catalog/data/startup_detail_mock.dart';
import 'package:mescla_invest/catalog/screens/startup_qa_full_screen.dart';

const _kPublicQa = [
  StartupPublicQa(
    question: 'Qual o diferencial da empresa?',
    answer: 'Tecnologia proprietária de baixo custo.',
  ),
  StartupPublicQa(
    question: 'Há certificações ambientais?',
    answer: 'Em processo de ISO 14001.',
  ),
];

const _kInvestorQa = [
  StartupPublicQa(
    question: 'Qual a projeção de receita?',
    answer: 'R\$ 5M até 2027.',
  ),
];

Widget _buildScreen({
  required bool canUseInvestorFilter,
}) {
  return MaterialApp(
    home: StartupQaFullScreen(
      publicQa: _kPublicQa,
      investorQa: _kInvestorQa,
      canUseInvestorFilter: canUseInvestorFilter,
    ),
  );
}

void main() {
  group('StartupQaFullScreen — não investidor', () {
    testWidgets('Exibe perguntas públicas', (tester) async {
      await tester.pumpWidget(_buildScreen(canUseInvestorFilter: false));
      await tester.pumpAndSettle();

      // O tile mostra "P: " como prefixo da pergunta.
      expect(find.textContaining('Qual o diferencial da empresa?'), findsOneWidget);
      expect(find.textContaining('Tecnologia proprietária de baixo custo.'), findsOneWidget);
    });

    testWidgets('Não exibe perguntas privadas de investidor', (tester) async {
      await tester.pumpWidget(_buildScreen(canUseInvestorFilter: false));
      await tester.pumpAndSettle();

      expect(find.textContaining('Qual a projeção de receita?'), findsNothing);
    });

    testWidgets('Não exibe SegmentedButton de filtro', (tester) async {
      await tester.pumpWidget(_buildScreen(canUseInvestorFilter: false));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<StartupQaVisibilityFilter>),
          findsNothing);
    });
  });

  group('StartupQaFullScreen — investidor', () {
    testWidgets('Exibe SegmentedButton de filtro', (tester) async {
      await tester.pumpWidget(_buildScreen(canUseInvestorFilter: true));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<StartupQaVisibilityFilter>),
          findsOneWidget);
    });

    testWidgets('Por padrão exibe todas as perguntas (públicas + privadas)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(canUseInvestorFilter: true));
      await tester.pumpAndSettle();

      // O tile mostra "P: " como prefixo da pergunta.
      expect(find.textContaining('Qual o diferencial da empresa?'), findsOneWidget);
      expect(find.textContaining('Qual a projeção de receita?'), findsOneWidget);
    });

    testWidgets('Filtrar apenas públicas oculta perguntas privadas', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(canUseInvestorFilter: true));
      await tester.pumpAndSettle();

      // Tap no segmento "Públicas"
      await tester.tap(find.text('Públicas'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Qual o diferencial da empresa?'), findsOneWidget);
      expect(find.textContaining('Qual a projeção de receita?'), findsNothing);
    });

    testWidgets('Filtrar apenas privadas oculta perguntas públicas', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(canUseInvestorFilter: true));
      await tester.pumpAndSettle();

      // Tap no segmento "Privadas"
      await tester.tap(find.text('Privadas'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Qual a projeção de receita?'), findsOneWidget);
      expect(find.textContaining('Qual o diferencial da empresa?'), findsNothing);
    });
  });

  group('StartupQaFullScreen — lista vazia', () {
    testWidgets('Exibe mensagem quando não há perguntas (não investidor)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupQaFullScreen(
            publicQa: [],
            investorQa: [],
            canUseInvestorFilter: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Não há perguntas públicas.'), findsOneWidget);
    });

    testWidgets('Exibe mensagem quando não há perguntas (investidor — todas)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupQaFullScreen(
            publicQa: [],
            investorQa: [],
            canUseInvestorFilter: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Não há perguntas nesta startup.'),
        findsOneWidget,
      );
    });
  });
}
