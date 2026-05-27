//Autor principal: Miguel Costacurta - 25003110

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/biometric_enrollment_storage.dart';
import '../services/session_persistence_service.dart';
import '../services/user_firestore_service.dart';
import 'biometric_unlock_screen.dart';
import 'login_screen.dart';

/// Primeira rota após o splash: no arranque a frio, por omissão fecha a sessão Firebase
/// para voltar ao login. Se a biometria estiver activa, a sessão de 24h ainda válida
/// e o aparelho inscrito, mantemos o utilizador autenticado e mostramos o desbloqueio
/// biométrico.
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _ready = false;

  /// Se `true`, o [BiometricUnlockScreen] substitui o login até ao desbloqueio.
  bool _startWithBiometricUnlock = false;

  static bool _firebaseAvailable() {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool _mobileNativeBiometrics() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(Duration.zero);
    if (!_firebaseAvailable()) {
      if (mounted) {
        setState(() => _ready = true);
      }
      return;
    }
    try {
      if (Firebase.apps.isNotEmpty) {
        final User? user = FirebaseAuth.instance.currentUser;
        final bool sessaoQuente =
            await SessionPersistenceService.isRecordedSessionValid();

        if (user != null &&
            _mobileNativeBiometrics() &&
            sessaoQuente &&
            await UserFirestoreService.fetchBiometricEnabled() &&
            await BiometricEnrollmentStorage.isEnrolledForUser(user.uid)) {
          if (mounted) {
            setState(() {
              _ready = true;
              _startWithBiometricUnlock = true;
            });
          }
          return;
        }

        // Preferência no servidor sem inscrição neste aparelho (ex.: dados locais apagados).
        if (user != null &&
            _mobileNativeBiometrics() &&
            sessaoQuente &&
            await UserFirestoreService.fetchBiometricEnabled() &&
            !await BiometricEnrollmentStorage.isEnrolledForUser(user.uid)) {
          try {
            await UserFirestoreService.setBiometricEnabled(false);
          } catch (_) {
            // Ignorado: utilizador seguirá para login; próximo arranque pode reconciliar.
          }
        }

        if (user != null) {
          await FirebaseAuth.instance.signOut();
        }
        await SessionPersistenceService.clearSessionDeadline();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthGateScreen] bootstrap: $e');
      }
    }
    if (mounted) {
      setState(() {
        _ready = true;
        _startWithBiometricUnlock = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_startWithBiometricUnlock) {
      return const BiometricUnlockScreen();
    }
    return const LoginScreen();
  }
}
