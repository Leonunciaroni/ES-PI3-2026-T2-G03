import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Importante adicionar
import 'firebase_options.dart'; // Arquivo que o FlutterFire CLI gerou

import 'theme/app_colors.dart';
import 'screens/login_screen.dart';

void main() async {
  // 1. Garante que os bindings do Flutter estejam inicializados antes de chamar código nativo
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa o Firebase com as configurações geradas para a plataforma atual
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      home: const LoginScreen(),
    );
  }
}
