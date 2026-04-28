// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Ecrãs abertos a partir do Perfil (Segurança, Ajuda, …) reutilizam o mesmo
// gradiente e barra de voltar, alinhados ao [MesclaMainShell].

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// [Scaffold] com fundo em gradiente Mescla, seta de voltar e título.
class MesclaSubpageScaffold extends StatelessWidget {
  const MesclaSubpageScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final gradientColors = AppColors.shellGradientColors(theme.brightness);
    final base = gradientColors.last;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.shellOverlayStyle(theme.brightness),
      child: Scaffold(
        backgroundColor: base,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back, color: onSurface),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                      ),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
