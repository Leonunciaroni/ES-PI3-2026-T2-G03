// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Constrói [ThemeData] claro e escuro com Material 3 ([useMaterial3]) e a cor de marca
// [AppColors.seedPurple], seguindo a documentação de temas da Google.

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema claro: já usado historicamente no app; mantém o fundo do [Scaffold] em branco.
ThemeData buildMesclaLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.seedPurple,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.seedPurple,
    onPrimary: const Color(0xFFFFFFFF),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.gradientBottom,
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.7),
      ),
    ),
  );
}

/// Tema escuro: [ColorScheme.fromSeed] com o mesmo roxo da marca e superfícies escuras.
ThemeData buildMesclaDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.seedPurple,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.seedPurple,
    onPrimary: const Color(0xFFFFFFFF),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.gradientBottomDark,
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.65),
      ),
    ),
  );
}
