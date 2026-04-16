// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Entrada do app: tema Mescla Invest + ecrã mínimo só para pré-visualizar a navbar.

import 'package:flutter/material.dart';

import 'theme/app_colors.dart';
import 'theme/app_scroll_behavior.dart';
import 'widgets/mescla_bottom_nav_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // [ColorScheme.fromSeed] gera tons harmonizados; [copyWith] fixa o roxo da marca.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seedPurple,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.seedPurple,
      onPrimary: const Color(0xFFFFFFFF),
    );

    return MaterialApp(
      title: 'Mescla Invest',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.gradientBottom,
      ),
      home: const _NavBarDemo(),
    );
  }
}

/// Ecrã mínimo só para pré-visualizar a navbar em execução (sem outras features).
///
/// Quando integrares no projeto completo, substitui isto por um shell com
/// [IndexedStack] e as tuas telas reais.
class _NavBarDemo extends StatefulWidget {
  const _NavBarDemo();

  @override
  State<_NavBarDemo> createState() => _NavBarDemoState();
}

class _NavBarDemoState extends State<_NavBarDemo> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Separador selecionado: $_index',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
      bottomNavigationBar: MesclaBottomNavBar(
        selectedIndex: _index,
        onItemTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
