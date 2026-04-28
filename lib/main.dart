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

// Host do emulador visto pelo Android Emulator:
// - 10.0.2.2 aponta para o localhost da máquina host.
// Troque por um IP real se rodar em dispositivo físico na mesma rede.
const _emulatorHost = '10.0.2.2';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supportsFirebaseCurrentPlatform()) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check: em debug usa provider de debug (evita o aviso nativo e permite
    // testar com enforcement ligado no Firebase Console). Registe o token de
    // debug que aparece no log na consola Firebase → App Check → Apps → Debug.
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    }

    // Em debug, aponta o Functions para o emulador local.
    // Rode: firebase emulators:start --only functions,firestore
    //
    // Nota: useAuthEmulator foi removido intencionalmente pois o emulador de
    // Auth não está sendo utilizado. Adicioná-lo sem o emulador de Auth rodando
    // interfere com a chamada das callables mesmo para usuários não autenticados.
    //
    // try/catch: em hot-restart o main() é reexecutado mas o singleton nativo
    // do Firebase persiste; sem o catch um erro aqui bloquearia o restante do init.
    if (kDebugMode) {
      try {
        FirebaseFunctions.instanceFor(region: 'us-central1')
            .useFunctionsEmulator(_emulatorHost, 5001);
      } catch (_) {
        // Já configurado (hot-restart) — ignorar.
      }
    }
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