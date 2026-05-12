// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Envolve o pacote `local_auth`: o SO confirma identidade (Face ID, Touch ID, digital).
// Nunca enviamos dados biométricos para o servidor — só um resultado local sim/não.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Resultado simplificado para a UI tratar fallback (ex.: voltar à senha).
enum BiometricAuthOutcome {
  success,
  cancelledByUser,
  notAvailable,
  lockedOut,
  error,
}

/// Serviço mínimo de autenticação biométrica local.
class BiometricAuthService {
  BiometricAuthService._();

  static final BiometricAuthService instance = BiometricAuthService._();

  final LocalAuthentication _local = LocalAuthentication();

  /// O hardware pode desbloquear com biometria (digital, face, etc.)?
  Future<bool> deviceCanUseBiometrics() async {
    try {
      final supported = await _local.isDeviceSupported();
      if (!supported) return false;
      final can = await _local.canCheckBiometrics;
      final types = await _local.getAvailableBiometrics();
      // Android: em Samsung/tablets o rosto costuma ser classe "weak". O plugin pode
      // reportar tipos em [getAvailableBiometrics] mesmo quando [canCheckBiometrics] é false.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return can || types.isNotEmpty;
      }
      return can;
    } catch (_) {
      return false;
    }
  }

  /// Texto amigável para mostrar nas definições (tipo de leitor disponível).
  Future<String> describeHardwareForUi() async {
    try {
      final types = await _local.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) {
        return 'Face ID / reconhecimento facial';
      }
      if (types.contains(BiometricType.fingerprint)) {
        return 'Impressão digital';
      }
      if (types.contains(BiometricType.iris)) {
        return 'Iris';
      }
      if (types.contains(BiometricType.weak)) {
        return 'Reconhecimento facial / biometria do sistema (p.ex. Samsung)';
      }
      if (types.contains(BiometricType.strong)) {
        return 'Biometria forte do sistema';
      }
    } catch (_) {
      // Em testes unitários ou plugin indisponível, caímos no texto genérico.
    }
    return 'Biometria (configurada no telemóvel)';
  }

  /// No **Android**, `biometricOnly: true` restringe a biometria "forte" e muitas vezes
  /// **bloqueia só rosto** (caso típico Samsung). No **iOS** mantemos `true` para Face ID
  /// alinhado à API. Com `false` no Android o SO pode oferecer rosto e, se precisar, PIN/padrão.
  ///
  /// [skipPluginAvailabilityPrecheck]: no desbloqueio e nas operações sensíveis o utilizador
  /// já activou a biometria nas definições; nalguns aparelhos `deviceCanUseBiometrics` mente
  /// e escondia o fluxo. Com `true` vamos directo ao `authenticate` do SO.
  Future<BiometricAuthOutcome> authenticate({
    required String localizedReason,
    bool skipPluginAvailabilityPrecheck = false,
  }) async {
    try {
      if (!skipPluginAvailabilityPrecheck) {
        final available = await deviceCanUseBiometrics();
        if (!available) {
          return BiometricAuthOutcome.notAvailable;
        }
      }

      final bool biometricOnlyIos =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

      final bool ok = await _local.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnlyIos,
        ),
      );
      return ok ? BiometricAuthOutcome.success : BiometricAuthOutcome.cancelledByUser;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[BiometricAuthService] ${e.code}: ${e.message}');
      }
      // Códigos comuns do plugin Android / iOS.
      final c = e.code.toLowerCase();
      if (c.contains('lockedout') || c.contains('lockout')) {
        return BiometricAuthOutcome.lockedOut;
      }
      if (c.contains('not_enrolled') || c.contains('notavailable')) {
        return BiometricAuthOutcome.notAvailable;
      }
      if (c.contains('user_cancel') || c.contains('canceled')) {
        return BiometricAuthOutcome.cancelledByUser;
      }
      return BiometricAuthOutcome.error;
    } catch (_) {
      return BiometricAuthOutcome.error;
    }
  }

  /// Mensagem curta em português para [SnackBar] ou erro na UI.
  static String messageForOutcome(BiometricAuthOutcome o) {
    switch (o) {
      case BiometricAuthOutcome.success:
        return 'Autenticação biométrica concluída.';
      case BiometricAuthOutcome.cancelledByUser:
        return 'Autenticação cancelada.';
      case BiometricAuthOutcome.notAvailable:
        return 'Biometria indisponível neste dispositivo ou desligada nas definições do sistema.';
      case BiometricAuthOutcome.lockedOut:
        return 'Biometria bloqueada por várias tentativas falhadas. Desbloqueie no sistema ou use a senha.';
      case BiometricAuthOutcome.error:
        return 'Não foi possível usar a biometria. Use a senha.';
    }
  }
}
