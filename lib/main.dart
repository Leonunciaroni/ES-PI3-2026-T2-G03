import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth/screens/login_screen.dart';
import 'firebase_dev_setup.dart';
import 'firebase_options.dart';
import 'theme/app_scroll_behavior.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supportsFirebaseCurrentPlatform()) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    configureFirebaseFunctionsEmulatorIfNeeded();
  }

  // Lê o tema guardado no cache (shared_preferences) antes do primeiro frame.
  await themeModeController.load();

  runApp(const MyApp());
}

bool _supportsFirebaseCurrentPlatform() {
  if (kIsWeb) {
    return true;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Raiz do app: [ListenableBuilder] reconstrói quando [themeModeController] muda.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeModeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Mescla Invest',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          theme: buildMesclaLightTheme(),
          darkTheme: buildMesclaDarkTheme(),
          themeMode: themeModeController.themeMode,
          home: const LoginScreen(),
        );
      },
    );
  }
}
