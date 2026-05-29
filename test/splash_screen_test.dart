import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mescla_invest/auth/screens/auth_gate_screen.dart';
import 'package:mescla_invest/splash/intro_video_loader.dart';
import 'package:mescla_invest/splash/screens/splash_screen.dart';

void main() {
  tearDown(() async {
    await IntroVideoLoader.disposePrepared();
  });

  testWidgets('Splash com skipVideo navega para AuthGateScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(skipVideo: true),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AuthGateScreen), findsOneWidget);
  });

  testWidgets('Toque na splash navega para AuthGateScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(skipVideo: true),
      ),
    );

    await tester.pump();
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.byType(AuthGateScreen), findsOneWidget);
  });
}
