// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import 'package:flutter/material.dart';

/// Cores e gradientes centralizados para o Mescla Invest.
///
/// Mantemos constantes nomeadas para a equipe alterar a identidade visual
abstract final class AppColors {
  /// Cor principal da marca (Figma) e semente do tema.
  static const Color seedPurple = Color(0xFF6234EA);

  /// Tom muito claro no topo do gradiente (mistura de lilás com neutro).
  static const Color gradientTop = Color(0xFFF3F0FA);

  /// Base do gradiente (branco).
  static const Color gradientBottom = Color(0xFFFFFFFF);

  /// Texto secundário (subtítulos e rótulos).
  static const Color textSecondary = Color(0xFF6B7280);

  /// Borda suave dos campos no cartão branco.
  static const Color fieldBorder = Color(0xFFE5E7EB);

  /// Sombra do botão principal (roxo semitransparente).
  static Color primaryShadow(ColorScheme scheme) =>
      scheme.primary.withValues(alpha: 0.35);
}
