// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Testes de widget focados na tela de detalhes da startup.
//
// Correm com: flutter test test/startup_detail_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/catalog/data/startup_detail_mock.dart';
import 'package:mescla_invest/catalog/screens/startup_detail_screen.dart';
import 'package:mescla_invest/theme/app_colors.dart';

/// [MaterialApp] mínimo com o mesmo tema roxo do app, para a tela usar cores corretas.
Widget _wrapStartupDetailScreen() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.seedPurple,
    brightness: Brightness.light,
  ).copyWith(primary: AppColors.seedPurple, onPrimary: const Color(0xFFFFFFFF));

  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.gradientBottom,
    ),
    home: StartupDetailScreen(catalog: kPreviewCatalogStartup),
  );
}

void main() {
  group('StartupDetailScreen', () {
    testWidgets('mostra CTA Investir e nome da startup', (tester) async {
      await tester.pumpWidget(_wrapStartupDetailScreen());
      await tester.pumpAndSettle();

      expect(find.text('Investir Agora'), findsOneWidget);
      expect(find.text('GreenFlow'), findsOneWidget);
    });

    testWidgets('Membros-Chave tem Saber mais em cada linha', (tester) async {
      await tester.pumpWidget(_wrapStartupDetailScreen());
      await tester.pumpAndSettle();

      expect(find.text('Membros-Chave'), findsOneWidget);
      expect(find.text('Saber mais'), findsNWidgets(3));
    });
  });
}
