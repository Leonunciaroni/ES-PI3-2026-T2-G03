// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cores e gradientes centralizados para o Mescla Invest.
///
/// Mantemos constantes nomeadas para a equipe alterar a identidade visual
abstract final class AppColors {
  /// Cor principal da marca (Figma) e semente do tema.
  static const Color seedPurple = Color(0xFF6234EA);

  /// Logo da marca (`flutter: assets:` → `assets/images/`).
  static const String mesclaLogoAsset = 'assets/images/mescla_logo.png';

  /// Variante do logo para fundos escuros (mesma área de layout que [mesclaLogoAsset]).
  static const String mesclaLogoDarkAsset = 'assets/images/mescla_logo_dark.png';

  /// Tom muito claro no topo do gradiente (mistura de lilás com neutro).
  static const Color gradientTop = Color(0xFFF3F0FA);

  /// Base do gradiente (branco).
  static const Color gradientBottom = Color(0xFFFFFFFF);

  /// Topo do gradiente em modo escuro (lilás muito escuro, alinhado à marca).
  static const Color gradientTopDark = Color(0xFF1E1B24);

  /// Base do gradiente escuro (Material ~ surface container).
  static const Color gradientBottomDark = Color(0xFF121212);

  /// Duas cores para [BoxDecoration] linear vertical (shell, login, subpáginas).
  ///
  /// No **escuro** usamos a mesma cor no topo e na base ([gradientBottomDark])
  /// para não criar faixa mais clara que o fundo “preto” do Material — evita o
  /// efeito de “caixa” atrás do cabeçalho nas abas Início e Carteira.
  static List<Color> shellGradientColors(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [gradientBottomDark, gradientBottomDark];
    }
    return const [gradientTop, gradientBottom];
  }

  /// Texto secundário (subtítulos e rótulos).
  static const Color textSecondary = Color(0xFF6B7280);

  /// Links e destaques de ação (2FA, CTAs secundários).
  static const Color linkAccent = Color(0xFF5E4CF0);

  /// Ícone e rótulo inativos na [MesclaBottomNavBar] (Figma ~ #9E9E9E).
  static const Color navBarInactive = Color(0xFF9E9E9E);

  /// Borda suave dos campos no cartão branco.
  static const Color fieldBorder = Color(0xFFE5E7EB);

  /// Fundo do campo de busca na tela Explorar / catálogo (Figma).
  static const Color searchFieldFill = Color(0xFFE2E2E2);

  /// AppBar / status bar em tom claro (evita fundo preto por transparência no Android).
  static const SystemUiOverlayStyle systemUiLightAppBar =
      SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// Sombra do botão principal (roxo semitransparente).
  static Color primaryShadow(ColorScheme scheme) =>
      scheme.primary.withValues(alpha: 0.35);

  /// Ícones da barra de estado: escuros em fundo claro, claros em fundo escuro.
  static SystemUiOverlayStyle shellOverlayStyle(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: gradientBottomDark,
        systemNavigationBarIconBrightness: Brightness.light,
      );
    }
    return SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
    );
  }

  // --- Harmonia com a tela Perfil (Material 3: surface / onSurface) -----------

  /// Cartão “branco” em listas: no escuro deixa de ser [Colors.white] puro.
  static Color themeCardSurface(ThemeData theme) {
    if (theme.brightness == Brightness.light) {
      return Colors.white;
    }
    return theme.colorScheme.surface;
  }

  /// Superfície acinzentada (resumos, chips inactivos): alinhada ao bloco CONTA.
  static Color themeMutedSurface(ThemeData theme) {
    if (theme.brightness == Brightness.light) {
      return const Color(0xFFF3F4F6);
    }
    return theme.colorScheme.surfaceContainerHigh;
  }

  /// Subtítulos e legendas: [textSecondary] no claro; [onSurfaceVariant] no escuro.
  static Color secondaryLabel(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.onSurfaceVariant;
    }
    return textSecondary;
  }

  /// Campo de busca (Catálogo / Balcão).
  static Color searchFieldFillForTheme(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.surfaceContainerHighest;
    }
    return searchFieldFill;
  }

  /// Divisória em cartão (Balcão, etc.).
  static Color cardDivider(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.outlineVariant;
    }
    return fieldBorder;
  }

  /// Itens inactivos da [MesclaBottomNavBar] no tema escuro.
  static Color bottomNavInactive(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.onSurfaceVariant;
    }
    return navBarInactive;
  }

  /// Fundo da cápsula flutuante da barra inferior (não forçar branco no dark).
  ///
  /// No escuro usa o mesmo tom que [shellGradientColors] / [scaffoldBackgroundColor]
  /// ([gradientBottomDark]) — [ColorScheme.surface] do seed costuma ser um cinza
  /// ligeiramente diferente e cria “halo” à volta da cápsula.
  static Color bottomNavBarShell(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return gradientBottomDark;
    }
    return Colors.white;
  }

  /// Trilho da [LinearProgressIndicator] em cartão escuro.
  static Color progressTrack(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.surfaceContainerHighest;
    }
    return const Color(0xFFF3F0FA);
  }

  /// Posição [left] do [MesclaChartReadingCard] sobre o gráfico. Evita
  /// [num.clamp] com mínimo > máximo quando a largura útil é menor que o cartão
  /// (erro: "Invalid argument(s): 4.0" na tela estreita).
  static double readingCardStackLeft({
    required double plotWidth,
    required double t,
    double minLeft = 4,
    double cardWidth = 158,
    double anchorOffset = 72,
  }) {
    if (plotWidth <= minLeft + cardWidth) {
      return minLeft;
    }
    final maxLeft = plotWidth - cardWidth;
    final raw = t * plotWidth - anchorOffset;
    return raw.clamp(minLeft, maxLeft);
  }
}
