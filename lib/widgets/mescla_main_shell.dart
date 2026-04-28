// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Layout “logado” partilhado: gradiente Mescla, área segura, cinco painéis em
// [IndexedStack] e [MesclaBottomNavBar]. Evita copiar o mesmo [Scaffold] em
// cada ecrã — basta passar os cinco corpos dos separadores.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'mescla_bottom_nav_bar.dart';

/// Número de separadores da barra inferior (Figma: Início, Carteira, Balcão,
/// Catálogo, Perfil).
const int kMesclaMainTabCount = 5;

/// Shell com navegação inferior para o fluxo principal após autenticação.
///
/// **Índices:** alinhados com [MesclaBottomNavBar] — 0 Início, 1 Carteira,
/// 2 Balcão, 3 Catálogo, 4 Perfil.
///
/// Telas de autenticação em `lib/auth/screens`, dashboard em `lib/dashboard/screens`;
/// carteira em `lib/carteira/screens`; catálogo em `lib/catalog/screens`.
/// A tela Balcão pode ser placeholder no dashboard até a integração em `dev`.
/// Rotas empurradas
/// (ex.: detalhe da startup) ficam **fora** deste shell.
class MesclaMainShell extends StatelessWidget {
  const MesclaMainShell({
    super.key,
    required this.selectedIndex,
    required this.onNavIndexChanged,
    required this.tabBodies,
  }) : assert(tabBodies.length == kMesclaMainTabCount);

  final int selectedIndex;
  final ValueChanged<int> onNavIndexChanged;

  /// Exatamente [kMesclaMainTabCount] widgets; o visível é o de [selectedIndex].
  final List<Widget> tabBodies;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gradientColors = AppColors.shellGradientColors(brightness);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.shellOverlayStyle(brightness),
      child: Scaffold(
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
              children: [
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    sizing: StackFit.expand,
                    children: tabBodies,
                  ),
                ),
                MesclaBottomNavBar(
                  selectedIndex: selectedIndex,
                  onItemTap: onNavIndexChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
