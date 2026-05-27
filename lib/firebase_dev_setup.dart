import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Porta [functions] em [firebase.json] (emulator).
const int kFirebaseFunctionsEmulatorPort = 5001;

/// Autenticação por telefone (SMS) no Android
/// -------------------------------------------
/// Se ao tocar em “Enviar código SMS” abrir o **navegador** com verificação “não sou robô”,
/// isso é o **reCAPTCHA de fallback** do Firebase Auth quando o **Play Integrity** não
/// consegue validar o app ou o ambiente é considerado arriscado (comum em **emulador**).
///
/// Não é possível desligar esse fallback no cliente para números **reais** — é exigência
/// de anti-fraude da Google.
///
/// **Emulador / desenvolvimento sem navegador:**
/// 1. Firebase Console → Construir → Authentication → Sign-in method → Phone →
///    **Phone numbers for testing** → adicione um E.164 (ex.: `+5511999999999`) e um
///    código de 6 dígitos fixo. Esse fluxo **não** envia SMS real e **não** força o
///    reCAPTCHA da mesma forma que números de produção.
/// 2. Crie um AVD com imagem **Google Play** (não só “Google APIs”), inicie o Play Store
///    uma vez e mantenha o Google Play Services atualizado — melhora Integrity no emulador.
/// 3. Confirme que SHA-1/SHA-256 do **debug** do PC que gera o build estão no app Android
///    no Firebase (mesmo `applicationId` que em `android/app/google-services.json`).
///
/// **Dispositivo físico:** com pacote + SHA corretos e, se for build da Play, fingerprints
/// da assinatura da loja + ligação Firebase↔Play, o fluxo costuma ficar **dentro do app**
/// sem abrir o browser.

/// Activa o host das Functions callable para o emulador local.
///
/// Usar com `flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true` e
/// `firebase emulators:start` (com Functions). Sem isto, o cliente chama
/// produção e recebe `not-found` se [simulateWallet] não estiver deployada.
///
/// Para celular Android físico na mesma rede, pode forçar o IP do PC:
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
