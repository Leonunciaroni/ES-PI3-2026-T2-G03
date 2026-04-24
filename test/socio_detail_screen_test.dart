// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Garante que a ficha mock do sócio monta sem erros (smoke test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/catalog/data/startup_detail_mock.dart';
import 'package:pi_iii/catalog/screens/socio_detail_screen.dart';
import 'package:pi_iii/theme/app_colors.dart';

Widget _wrapSocioDetail() {
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
    home: const SocioDetailScreen(
      data: kSocioMockRicardoSilveira,
      startupDisplayName: 'GreenFlow',
    ),
  );
}

void main() {
  group('SocioDetailScreen', () {
    testWidgets('mostra nome do sócio e secção de apresentação', (tester) async {
      await tester.pumpWidget(_wrapSocioDetail());
      await tester.pumpAndSettle();

      expect(find.text('Ricardo Silveira'), findsOneWidget);
      expect(find.text('GreenFlow'), findsOneWidget);
      expect(find.text('Apresentação institucional'), findsOneWidget);
      // Perfil rico do template não usa faixa de “placeholder”.
      expect(
        find.textContaining('Pré-visualização com dados fictícios'),
        findsNothing,
      );
    });

    testWidgets('perfil placeholder mostra faixa e várias secções', (tester) async {
      const membro = StartupTeamMember(
        name: 'Fulana Silva',
        role: 'Sócio — 40%',
        avatarColor: Color(0xFFE11D48),
      );
      final dados = socioDetailForTeamMember(membro);
      expect(dados.isMockPlaceholder, isTrue);

      final colorScheme = ColorScheme.fromSeed(
        seedColor: AppColors.seedPurple,
        brightness: Brightness.light,
      ).copyWith(primary: AppColors.seedPurple, onPrimary: const Color(0xFFFFFFFF));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            scaffoldBackgroundColor: AppColors.gradientBottom,
          ),
          home: SocioDetailScreen(
            data: dados,
            startupDisplayName: 'Startup Demo',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Pré-visualização com dados fictícios'),
        findsOneWidget,
      );
      expect(find.text('Formação académica'), findsOneWidget);
      expect(find.text('Competências principais'), findsOneWidget);
      expect(find.text('Fulana Silva'), findsOneWidget);
    });
  });
}
