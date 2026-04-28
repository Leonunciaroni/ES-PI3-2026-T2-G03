// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Wordmark Mescla com caixa de tamanho fixo: os PNGs claro/escuro podem ter proporções
// diferentes, mas [BoxFit.contain] dentro do mesmo [SizedBox] mantém o tamanho visual
// estável ao mudar o tema (incluindo "padrão do sistema").

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Logo da marca: escolhe o asset conforme [Theme.of(context).brightness].
class MesclaBrandLogo extends StatelessWidget {
  const MesclaBrandLogo({
    super.key,
    this.boxWidth = 200,
    this.boxHeight = 52,
  });

  /// Largura máxima da caixa (o desenho encolhe com [BoxFit.contain] se for largo).
  final double boxWidth;

  /// Altura máxima da caixa (igual para claro e escuro).
  final double boxHeight;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final path = brightness == Brightness.dark
        ? AppColors.mesclaLogoDarkAsset
        : AppColors.mesclaLogoAsset;

    final theme = Theme.of(context);
    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        // Centrado na caixa: PNGs claro/escuro têm área útil diferente; alinhar à
        // esquerda deixava o wordmark visualmente deslocado (ex.: login no dark).
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              'mescla invest',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Wordmark nas telas de **autenticação** (login, criar conta, recuperar senha, 2FA):
/// mesma caixa, centrado, em tema claro e escuro — um único critério visual.
class MesclaAuthHeaderLogo extends StatelessWidget {
  const MesclaAuthHeaderLogo({super.key});

  /// Largura da área do PNG ([MesclaBrandLogo]).
  static const double boxWidth = 200;

  /// Altura da área (wordmark + linha “invest” nos assets).
  static const double boxHeight = 88;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: MesclaBrandLogo(
        boxWidth: boxWidth,
        boxHeight: boxHeight,
      ),
    );
  }
}
