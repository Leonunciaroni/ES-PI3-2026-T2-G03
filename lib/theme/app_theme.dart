// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Constrói [ThemeData] claro e escuro com Material 3 ([useMaterial3]) e a cor de marca
// [AppColors.seedPurple], seguindo a documentação de temas da Google.

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Transição **fade + micro-deslocamento** para [MaterialPageRoute].
///
/// O SDK nem sempre expõe [FadeThroughPageTransitionsBuilder] (depende da versão
/// do Flutter); este builder é estável, curto (~300 ms) e próximo do que muitas
/// apps usam: novo ecrã surge com opacidade e um ligeiro movimento vertical.
class MesclaFadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const MesclaFadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Transição entre ecrãs empilhados ([Navigator.push] com [MaterialPageRoute]).
PageTransitionsTheme get mesclaPageTransitionsTheme {
  return PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      for (final TargetPlatform p in TargetPlatform.values)
        p: const MesclaFadeSlidePageTransitionsBuilder(),
    },
  );
}

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
    pageTransitionsTheme: mesclaPageTransitionsTheme,
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
    pageTransitionsTheme: mesclaPageTransitionsTheme,
    scaffoldBackgroundColor: AppColors.gradientBottomDark,
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.65),
      ),
    ),
  );
}
