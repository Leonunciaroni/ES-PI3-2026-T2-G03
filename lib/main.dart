import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/screens/auth_gate_screen.dart';
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
    await _activateFirebaseAppCheck();
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

/// Em builds de debug usa providers de debug (copie o token do log à primeira corrida e
/// registe-o em Firebase Console → App Check → Apps → gerir tokens de debug).
/// Em release usa Play Integrity / Device Check.
Future<void> _activateFirebaseAppCheck() async {
  if (kIsWeb) {
    return;
  }
  try {
    if (kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidDebugProvider(),
        providerApple: const AppleDebugProvider(),
      );
      // Registe este token em Firebase Console → App Check → Apps → token de debug.
      try {
        final token = await FirebaseAppCheck.instance.getToken();
        if (token != null && token.isNotEmpty) {
          debugPrint('App Check debug token: $token');
        }
      } catch (e) {
        debugPrint('App Check getToken failed: $e');
      }
    } else {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerApple: const AppleDeviceCheckProvider(),
      );
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('App Check activate failed: $e');
    }
  }
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
          supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildMesclaLightTheme(),
          darkTheme: buildMesclaDarkTheme(),
          themeMode: themeModeController.themeMode,
          home: const AuthGateScreen(),
        );
      },
    );
  }
}
