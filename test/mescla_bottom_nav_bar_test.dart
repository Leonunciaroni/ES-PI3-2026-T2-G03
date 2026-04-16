// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Testes de widget da [MesclaBottomNavBar]: verificamos rótulos do Figma e se o
// toque num separador atualiza o estado do widget pai (simulação do fluxo real).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/theme/app_colors.dart';
import 'package:pi_iii/widgets/mescla_bottom_nav_bar.dart';

/// “Arnês” de teste: um [StatefulWidget] mínimo que contém a navbar + um texto
/// com o índice atual. Assim conseguimos provar que [onItemTap] foi chamado.
///
/// Em testes, o app real não corre — construímos só a árvore necessária com
/// [pumpWidget] e simulamos toques com [WidgetTester.tap].
class _NavBarHarness extends StatefulWidget {
  const _NavBarHarness();

  @override
  State<_NavBarHarness> createState() => _NavBarHarnessState();
}

class _NavBarHarnessState extends State<_NavBarHarness> {
  /// Índice do separador selecionado (mesma ideia do ecrã real).
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Tema alinhado ao [MyApp]: roxo da marca para a pílula ativa.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.seedPurple,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.seedPurple,
          onPrimary: Colors.white,
        ),
      ),
      home: Scaffold(
        // Corpo só mostra o índice — facilita o [expect] depois do toque.
        body: Text('idx:$index'),
        bottomNavigationBar: MesclaBottomNavBar(
          selectedIndex: index,
          onItemTap: (i) => setState(() => index = i),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'MesclaBottomNavBar: rótulos Figma, CARTEIRA e troca para índice 2 (CATÁLOGO)',
    (tester) async {
      // 1) Monta o widget na “superfície” de teste e espera animações terminarem.
      await tester.pumpWidget(const _NavBarHarness());
      await tester.pumpAndSettle();

      // 2) Confirma que os quatro rótulos existem (inclui CARTEIRA, não BALCÃO).
      expect(find.text('INÍCIO'), findsOneWidget);
      expect(find.text('CARTEIRA'), findsOneWidget);
      expect(find.text('CATÁLOGO'), findsOneWidget);
      expect(find.text('PERFIL'), findsOneWidget);

      // 3) Estado inicial: índice 0.
      expect(find.text('idx:0'), findsOneWidget);

      // 4) Simula toque no terceiro separador (CATÁLOGO → índice 2).
      await tester.tap(find.text('CATÁLOGO'));
      await tester.pumpAndSettle();

      // 5) O texto do corpo deve refletir o novo índice.
      expect(find.text('idx:2'), findsOneWidget);
    },
  );
}
