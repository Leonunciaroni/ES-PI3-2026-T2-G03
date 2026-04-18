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

  /// Tom muito claro no topo do gradiente (mistura de lilás com neutro).
  static const Color gradientTop = Color(0xFFF3F0FA);

  /// Base do gradiente (branco).
  static const Color gradientBottom = Color(0xFFFFFFFF);

  /// Texto secundário (subtítulos e rótulos).
  static const Color textSecondary = Color(0xFF6B7280);

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
}
