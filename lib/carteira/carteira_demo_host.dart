// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// **Só para esta branch:** ecrã mínimo com gradiente Mescla + [CarteiraScreen].
// Em `dev`, o login e o shell substituem isto; aqui evita ficheiros extra fora
// de `lib/carteira/` só para demo local.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'screens/carteira_screen.dart';

/// Corpo inicial da app enquanto a integração completa não está em `dev`.
class CarteiraDemoHost extends StatelessWidget {
  const CarteiraDemoHost({super.key});

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
          // O [SafeArea] fica aqui; a tela usa wrapWithSafeArea: false para não duplicar.
          child: const SafeArea(
            child: CarteiraScreen(wrapWithSafeArea: false),
          ),
        ),
      ),
    );
  }
}
