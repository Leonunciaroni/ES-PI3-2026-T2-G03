import 'package:flutter/material.dart';

/// Scroll sem o overscroll “stretch” do Android (Material 3), que estica toda a
/// tela ao puxar rápido no fim da lista e costuma confundir no emulador.
///
/// Mantém [ClampingScrollPhysics] (sem “bounce” de iOS no Android).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
