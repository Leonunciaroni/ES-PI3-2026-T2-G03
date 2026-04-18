import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_iii/auth/screens/two_factor_verification_screen.dart';

/// Empilha a tela 2FA como no preview, para [Navigator.canPop] ser true após sucesso.
class _StubWithPushedTwoFactor extends StatefulWidget {
  const _StubWithPushedTwoFactor();

  @override
  State<_StubWithPushedTwoFactor> createState() =>
      _StubWithPushedTwoFactorState();
}

class _StubWithPushedTwoFactorState extends State<_StubWithPushedTwoFactor> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const TwoFactorVerificationScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('stub_home')),
    );
  }
}

void main() {
  Future<void> enterCode(WidgetTester tester, String sixDigits) async {
    expect(sixDigits.length, 6);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), sixDigits[i]);
    }
  }

  testWidgets('Mostra título e campos OTP', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TwoFactorVerificationScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verificação de duas etapas'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('Validar sem 6 dígitos mostra SnackBar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TwoFactorVerificationScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Validar conta'));
    await tester.pump();

    expect(
      find.text('Informe os 6 dígitos do código.'),
      findsOneWidget,
    );
  });

  testWidgets('Código incorreto mostra falha', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TwoFactorVerificationScreen()),
    );
    await tester.pumpAndSettle();

    await enterCode(tester, '111111');
    await tester.tap(find.text('Validar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Falha na verificação!'), findsOneWidget);
  });

  testWidgets('Código 123456 mostra sucesso', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TwoFactorVerificationScreen()),
    );
    await tester.pumpAndSettle();

    await enterCode(tester, '123456');
    await tester.tap(find.text('Validar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Verificação concluída!'), findsOneWidget);
    expect(find.text('Redirecionando para Dashboard...'), findsOneWidget);

    // Liberta o Future.delayed do fluxo de sucesso (sem pop quando não há rota).
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets('Colar 123456 no primeiro campo permite validar com sucesso', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TwoFactorVerificationScreen()),
    );
    await tester.pumpAndSettle();

    final first = find.byType(TextField).first;
    await tester.enterText(first, '123456');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Validar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Verificação concluída!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets('Com rota inferior, sucesso executa pop após o atraso', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: _StubWithPushedTwoFactor()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verificação de duas etapas'), findsOneWidget);

    await enterCode(tester, '123456');
    await tester.tap(find.text('Validar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Verificação concluída!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.text('Verificação de duas etapas'), findsNothing);
    expect(find.text('stub_home'), findsOneWidget);
  });
}
