import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth/screens/login_screen.dart';
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
    _configureFirebaseFunctionsEmulator();
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

/// Em **debug**, permite apontar [FirebaseFunctions] para o emulador local.
///
/// Ative com:
/// `flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true`
///
/// No Android Emulator use `10.0.2.2` (mapeado para localhost da máquina); no iOS/desktop,
/// `localhost` funciona. A porta padrão do emulador de Functions é **5001**.
void _configureFirebaseFunctionsEmulator() {
  if (!kDebugMode) {
    return;
  }
  const useEmu = bool.fromEnvironment(
    'USE_FUNCTIONS_EMULATOR',
    defaultValue: false,
  );
  if (!useEmu) {
    return;
  }
  final String host = defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
  FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(
    host,
    5001,
  );
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
