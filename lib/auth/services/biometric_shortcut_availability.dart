// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Um único sítio para saber se o utilizador **quer** biometria nestes passos.
// Igual ao [AuthGateScreen]: Firestore + inscrição local — **sem** `deviceCanUseBiometrics`,
// porque em vários Samsung/tablets o plugin diz “não há biometria” e depois o diálogo funciona.

import 'package:firebase_auth/firebase_auth.dart';

import 'biometric_enrollment_storage.dart';
import 'user_firestore_service.dart';

class BiometricShortcutAvailability {
  BiometricShortcutAvailability._();

  /// Mesmas condições do desbloqueio ao abrir o app: preferência em `users/{uid}` e
  /// chave no armazenamento seguro. O SO só é chamado em [BiometricAuthService.authenticate].
  static Future<bool> userWantsBiometricShortcut() async {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;
    final bool pref = await UserFirestoreService.fetchBiometricEnabled();
    final bool inscrito =
        await BiometricEnrollmentStorage.isEnrolledForUser(u.uid);
    return pref && inscrito;
  }
}
