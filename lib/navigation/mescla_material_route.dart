// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Rotas com animação **garantida** (fade + leve slide), mesmo quando o
// [ThemeData.pageTransitionsTheme] não se aplica a todos os casos de
// [MaterialPageRoute] (ex.: fluxos empilhados a partir do shell com gradiente).
//
// Preferível usar isto nos fluxos Balcão, Catálogo → Detalhe, etc., para o
// comportamento ser igual em todas as plataformas.

import 'package:flutter/material.dart';

/// Fábrica de [PageRoute] com transição Mescla (fade + micro-deslocamento).
abstract final class MesclaMaterialRoute {
  MesclaMaterialRoute._();

  static const Duration kTransitionDuration = Duration(milliseconds: 320);
  static const Duration kReverseTransitionDuration = Duration(milliseconds: 280);

  /// Nova rota empilhada ou substituída ([push], [pushReplacement], …).
  static PageRoute<T> fadeSlide<T extends Object?>(
    Widget Function(BuildContext context) builder, {
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
      opaque: true,
      barrierDismissible: false,
      transitionDuration: kTransitionDuration,
      reverseTransitionDuration: kReverseTransitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
