import 'package:flutter/material.dart';

import 'screens/create_account_screen.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // fromSeed ajusta o primary para tons “Material”; fixamos a marca em #6234EA.
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
      home: const CreateAccountScreen(),
    );
  }
}
