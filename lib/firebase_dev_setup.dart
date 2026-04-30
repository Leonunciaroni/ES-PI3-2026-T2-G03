import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Porta [functions] em [firebase.json] (emulator).
const int kFirebaseFunctionsEmulatorPort = 5001;

/// Activa o host das Functions callable para o emulador local.
///
/// Usar com `flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true` e
/// `firebase emulators:start` (com Functions). Sem isto, o cliente chama
/// produção e recebe `not-found` se [simulateWallet] não estiver deployada.
///
/// Para telemóvel Android físico na mesma rede, pode forçar o IP do PC:
/// `--dart-define=FUNCTIONS_EMULATOR_HOST=192.168.x.x`
/// e acrescente esse IP em
/// `android/app/src/main/res/xml/network_security_config.xml` (domínio com
/// `cleartextTrafficPermitted`).
void configureFirebaseFunctionsEmulatorIfNeeded() {
  const useEmu = bool.fromEnvironment(
    'USE_FUNCTIONS_EMULATOR',
    defaultValue: false,
  );
  if (!useEmu) return;

  const customHost = String.fromEnvironment('FUNCTIONS_EMULATOR_HOST');
  final host = customHost.isNotEmpty
      ? customHost
      : kIsWeb
          ? 'localhost'
          : switch (defaultTargetPlatform) {
              TargetPlatform.android => '10.0.2.2',
              _ => '127.0.0.1',
            };

  FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(
    host,
    kFirebaseFunctionsEmulatorPort,
  );
}
