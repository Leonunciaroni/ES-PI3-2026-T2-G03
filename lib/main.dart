import 'package:flutter/material.dart';

import 'data/startup_detail_mock.dart';
import 'screens/startup_detail_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_scroll_behavior.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// Nesta branch só existe o fluxo de **detalhes da startup** (dados mock).
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.seedPurple,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.seedPurple,
          onPrimary: const Color(0xFFFFFFFF),
        );

    return MaterialApp(
      title: 'Mescla Invest — Detalhes',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.gradientBottom,
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ),
      home: StartupDetailScreen(data: startupDetailFor(kPreviewCatalogStartup)),
    );
  }
}
