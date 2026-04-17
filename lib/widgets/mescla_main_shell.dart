// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Layout “logado” partilhado: gradiente Mescla, área segura, quatro painéis em
// [IndexedStack] e [MesclaBottomNavBar]. Evita copiar o mesmo [Scaffold] em
// cada ecrã — basta passar os quatro corpos dos separadores.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'mescla_bottom_nav_bar.dart';

/// Número de separadores da barra inferior (Início, Balcão, Catálogo, Perfil).
const int kMesclaMainTabCount = 4;

/// Shell com navegação inferior para o fluxo principal após autenticação.
///
/// **Índices:** alinhados com [MesclaBottomNavBar] — 0 Início, 1 Balcão,
/// 2 Catálogo, 3 Perfil.
///
/// Telas de autenticação em [lib/auth/screens] (login, criar conta, recuperar senha) e rotas
/// empurradas (ex.: detalhe da startup) ficam **fora** deste shell.
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.gradientTop,
                AppColors.gradientBottom,
              ],
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
