// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ MIGUEL — ESTUDE ESTE ARQUIVO (ponte Flutter → servidor)                  │
// │                                                                          │
// │ Pedro escreveu; você CHAMA nas telas recover + verification.             │
// │                                                                          │
// │ 3 ações da Cloud Function `passwordReset`:                               │
// │   send    → envia OTP por e-mail (RecoverPasswordScreen)                 │
// │   verify  → valida OTP, devolve sessionToken (VerificationCodeScreen)    │
// │   confirm → troca senha com sessionToken (ResetPasswordScreen — Pedro)   │
// └──────────────────────────────────────────────────────────────────────────┘

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PasswordResetService {
  PasswordResetService({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _instance =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// action: "send" — dispara OTP (resposta neutra por segurança).
  Future<void> sendCode(String email) async {
    await _instance.httpsCallable('passwordReset').call<void>({
      'action': 'send',
      'email': email,
    });
  }

  /// action: "verify" — confere OTP; retorna sessionToken para etapa confirm.
  Future<String> verifyCode({required String email, required String code}) async {
    final result =
        await _instance.httpsCallable('passwordReset').call<Map<Object?, Object?>>({
      'action': 'verify',
      'email': email,
      'code': code,
    });
    final token = result.data['sessionToken'];
    return token is String ? token : '';
  }

  /// action: "confirm" — atualiza senha no Firebase Auth (Admin SDK no servidor).
  Future<void> confirmNewPassword({
    required String sessionToken,
    required String newPassword,
  }) async {
    await _instance.httpsCallable('passwordReset').call<void>({
      'action': 'confirm',
      'sessionToken': sessionToken,
      'newPassword': newPassword,
    });
  }

  static String messageForError(Object error) {
    if (error is FirebaseFunctionsException) {
      final code = _normalizeFunctionsCode(error.code);

      if (kDebugMode) {
        debugPrint(
          '[passwordReset] FirebaseFunctionsException code=$code '
          'message=${error.message} details=${error.details}',
        );
      }

      const httpStatusMessages = {
        'NOT_FOUND', 'INTERNAL', 'UNAVAILABLE', 'UNKNOWN',
        'PERMISSION_DENIED', 'UNAUTHENTICATED',
      };
      final serverMsg = error.message?.trim() ?? '';
      final isUserFacingMsg = serverMsg.isNotEmpty &&
          !httpStatusMessages.contains(serverMsg.toUpperCase());

      if (isUserFacingMsg &&
          (code == 'failed-precondition' || code == 'internal')) {
        return serverMsg;
      }

      switch (code) {
        case 'not-found':
          return 'Código expirado ou não encontrado. Solicite um novo.';
        case 'invalid-argument':
          return 'Código incorreto. Verifique e tente novamente.';
        case 'resource-exhausted':
          return 'Muitas tentativas incorretas. Solicite um novo código.';
        case 'internal':
          return 'Erro no servidor. Tente novamente em instantes.';
        case 'unauthenticated':
          return 'Sessão expirada. Faça login novamente.';
        case 'failed-precondition':
          return 'Configuração incompleta no servidor. Verifique SMTP ou contacte o suporte.';
        case 'permission-denied':
          return 'Acesso negado. Verifique App Check / regras do projeto Firebase.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Não foi possível ligar ao emulador/servidor. '
              'Confirme que `firebase emulators:start` está a correr e que o '
              'Android permite HTTP em debug (cleartext).';
        default:
          return 'Não foi possível concluir agora. Tente novamente.';
      }
    }
    return 'Não foi possível concluir agora. Tente novamente.';
  }

  static String _normalizeFunctionsCode(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw.toLowerCase().replaceAll('_', '-');
  }
}
