// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Serviço do app (Flutter) para o fluxo de **recuperação de senha** via OTP.
//
// Motivo:
// - O reset padrão do Firebase Auth envia um link (oobCode) e não um OTP de 6 dígitos.
// - Como as telas do protótipo foram desenhadas para OTP, chamamos a Function
//   callable `passwordReset` com 3 ações: send / verify / confirm.
//
// Contrato com o backend (Functions):
// - send   -> { sent: true } (sempre neutro, mesmo se o e-mail não existir)
// - verify -> { verified: true, sessionToken: string }
// - confirm-> { updated: true }

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PasswordResetService {
  PasswordResetService({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;

  /// As callables deste projeto rodam em `us-central1` (ver `functions/src/auth/...`).
  /// Usar `instanceFor` aqui evita mismatch de região entre app e emulator.
  FirebaseFunctions get _instance =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<void> sendCode(String email) async {
    // Dispara envio do OTP (não retorna erro se e-mail não existir, por segurança).
    await _instance.httpsCallable('passwordReset').call<void>({
      'action': 'send',
      'email': email,
    });
  }

  Future<String> verifyCode({required String email, required String code}) async {
    // Valida OTP e devolve um token de sessão temporário para a etapa confirm.
    final result =
        await _instance.httpsCallable('passwordReset').call<Map<Object?, Object?>>({
      'action': 'verify',
      'email': email,
      'code': code,
    });
    final token = result.data['sessionToken'];
    return token is String ? token : '';
  }

  Future<void> confirmNewPassword({
    required String sessionToken,
    required String newPassword,
  }) async {
    // Atualiza a senha no backend usando o token de sessão emitido em verify.
    await _instance.httpsCallable('passwordReset').call<void>({
      'action': 'confirm',
      'sessionToken': sessionToken,
      'newPassword': newPassword,
    });
  }

  static String messageForError(Object error) {
    if (error is FirebaseFunctionsException) {
      // O SDK pode devolver códigos em minúsculas com hífen (`not-found`) ou em
      // MAIÚSCULAS com underscore (`NOT_FOUND`) dependendo da plataforma/ponte.
      final code = _normalizeFunctionsCode(error.code);

      if (kDebugMode) {
        debugPrint(
          '[passwordReset] FirebaseFunctionsException code=$code '
          'message=${error.message} details=${error.details}',
        );
      }

      // Mensagens genéricas da infraestrutura (ex.: "NOT_FOUND" quando a function
      // não existe em produção ou o emulador não está rodando) são descartadas
      // para não confundir o usuário com texto técnico.
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

  /// Normaliza [FirebaseFunctionsException.code] para o formato `kebab-case`.
  static String _normalizeFunctionsCode(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw.toLowerCase().replaceAll('_', '-');
  }
}

