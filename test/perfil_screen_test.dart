import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/perfil/screens/perfil_screen.dart';

void main() {
  Widget buildPerfil({Stream<List<String>>? favoriteStartupIdsStream}) {
    return MaterialApp(
      home: Scaffold(
        body: PerfilScreen(
          wrapWithSafeArea: false,
          favoriteStartupIdsStream: favoriteStartupIdsStream,
        ),
      ),
    );
  }

  testWidgets('Perfil mostra título, CONTA e Sair da Conta', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPerfil());
    await tester.pumpAndSettle();

    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('CONTA'), findsOneWidget);
    expect(find.text('SESSÃO'), findsOneWidget);
    expect(find.text('Sair da Conta'), findsOneWidget);
    expect(find.text('Segurança e Privacidade'), findsOneWidget);
    expect(find.text('Lista de Desejos'), findsOneWidget);
  });

  testWidgets('Perfil mostra contador da lista de desejos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildPerfil(favoriteStartupIdsStream: Stream.value(const <String>[])),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 startups na lista de desejos'), findsOneWidget);

    await tester.pumpWidget(
      buildPerfil(favoriteStartupIdsStream: Stream.value(const <String>['s1'])),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 startup na lista de desejos'), findsOneWidget);

    await tester.pumpWidget(
      buildPerfil(
        favoriteStartupIdsStream: Stream.value(const <String>['s1', 's2']),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 startups na lista de desejos'), findsOneWidget);
  });

  testWidgets('Toque em Segurança abre subpágina', (WidgetTester tester) async {
    await tester.pumpWidget(buildPerfil());
    await tester.pumpAndSettle();

    final seguranca = find.text('Segurança e Privacidade');
    await tester.ensureVisible(seguranca);
    await tester.pumpAndSettle();
    await tester.tap(seguranca);
    await tester.pumpAndSettle();

    // Sem sessão: não há interruptores; texto alinhado a [SegurancaPrivacidadeScreen].
    expect(
      find.text(
        'Faça login para gerenciar duas etapas, biometria e outros controles de segurança.',
      ),
      findsOneWidget,
    );
    expect(find.text('Trocar senha por e-mail'), findsOneWidget);
  });

  testWidgets('Sair da Conta abre diálogo de confirmação', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPerfil());
    await tester.pumpAndSettle();

    final sair = find.text('Sair da Conta');
    await tester.ensureVisible(sair);
    await tester.pumpAndSettle();
    await tester.tap(sair);
    await tester.pumpAndSettle();

    expect(find.text('Sair do aplicativo?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Sair do aplicativo?'), findsNothing);
    expect(find.text('Perfil'), findsOneWidget);
  });
}
