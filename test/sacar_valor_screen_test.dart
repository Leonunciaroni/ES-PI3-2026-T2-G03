// Testes TDD para SacarValorScreen.
// Com usarFirebaseParaSessao: false, as chaves PIX são geridas só em memória.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/carteira/models/pix_chave_ui.dart';
import 'package:mescla_invest/carteira/screens/sacar_valor_screen.dart';

final _kChaves = [
  PixChaveUi(
    id: 'k1',
    tipoLabel: 'E-mail',
    valor: 'user@test.com',
  ),
  PixChaveUi(
    id: 'k2',
    tipoLabel: 'CPF',
    valor: '12345678901',
  ),
];

Widget _buildScreen({List<PixChaveUi>? chaves}) {
  return MaterialApp(
    home: SacarValorScreen(
      chavesPixIniciais: chaves ?? _kChaves,
      onChavesAlteradas: (_) {},
      usarFirebaseParaSessao: false,
    ),
  );
}

void main() {
  group('SacarValorScreen — UI', () {
    testWidgets('Renderiza sem crash', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Exibe campo de valor', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('Exibe saldo em BRL (demo do convidado)', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // Saldo demo: R$ 12.450,00
      expect(find.textContaining('12'), findsWidgets);
    });

    testWidgets('Exibe label "Saldo disponível"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Saldo'), findsWidgets);
    });
  });

  group('SacarValorScreen — seleção de chave PIX', () {
    testWidgets('Exibe as chaves PIX disponíveis', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('E-mail'), findsWidgets);
    });

    testWidgets('Renderiza com lista de chaves vazia', (tester) async {
      await tester.pumpWidget(_buildScreen(chaves: []));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('SacarValorScreen — visibilidade do saldo', () {
    testWidgets('Botão de olho para ocultar/mostrar saldo está presente', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.visibility_outlined),
        findsWidgets,
      );
    });
  });
}
