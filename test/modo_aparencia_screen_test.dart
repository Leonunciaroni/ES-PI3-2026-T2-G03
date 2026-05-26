// Testes TDD para ModoAparenciaScreen.
// Usa [themeModeController] global — sem Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/perfil/screens/modo_aparencia_screen.dart';
import 'package:mescla_invest/theme/theme_mode_controller.dart';

Widget _buildScreen() {
  return const MaterialApp(home: ModoAparenciaScreen());
}

void main() {
  setUp(() {
    // Garante que o controller inicia no estado padrão entre testes.
    themeModeController.setMode(ThemeMode.system);
  });

  group('ModoAparenciaScreen — UI', () {
    testWidgets('Exibe título "Modo de Aparência"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Modo de Aparência'), findsOneWidget);
    });

    testWidgets('Exibe opção "Claro"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Claro'), findsOneWidget);
    });

    testWidgets('Exibe opção "Escuro"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Escuro'), findsOneWidget);
    });

    testWidgets('Exibe opção "Padrão do sistema"', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Padrão do sistema'), findsOneWidget);
    });
  });

  group('ModoAparenciaScreen — seleção', () {
    testWidgets('Padrão do sistema está selecionado inicialmente',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(themeModeController.themeMode, ThemeMode.system);
    });

    testWidgets('Toque em "Claro" altera o modo para light', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();

      expect(themeModeController.themeMode, ThemeMode.light);
    });

    testWidgets('Toque em "Escuro" altera o modo para dark', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Escuro'));
      await tester.pumpAndSettle();

      expect(themeModeController.themeMode, ThemeMode.dark);
    });

    testWidgets('Toque em "Padrão do sistema" altera o modo para system',
        (tester) async {
      // Primeiro define modo light para garantir que a mudança é detectada.
      themeModeController.setMode(ThemeMode.light);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Padrão do sistema'));
      await tester.pumpAndSettle();

      expect(themeModeController.themeMode, ThemeMode.system);
    });

    testWidgets('Após selecionar "Escuro", ícone de check aparece ao lado',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Escuro'));
      await tester.pumpAndSettle();

      // Ícone de check (Icons.check_rounded) aparece na opção selecionada.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
