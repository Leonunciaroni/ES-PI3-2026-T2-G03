import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth/screens/login_screen.dart';
import 'firebase_options.dart';
import 'theme/app_colors.dart';
import 'theme/app_scroll_behavior.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supportsFirebaseCurrentPlatform()) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const MyApp());
}

bool _supportsFirebaseCurrentPlatform() {
  if (kIsWeb) {
    return true;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // fromSeed ajusta o primary para tons "Material"; fixamos a marca em #6234EA.
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
