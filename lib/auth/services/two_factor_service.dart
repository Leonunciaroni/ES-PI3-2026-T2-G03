import 'package:cloud_functions/cloud_functions.dart';

/// Serviço que chama as Firebase Functions de 2FA.
///
/// Usa [FirebaseFunctions.instance] para invocar a callable única `twoFactor`
/// com `action: send` ou `action: verify`.
///
/// Para testes, subclasse e sobrescreva [sendCode] e [verifyCode]
/// sem precisar de Firebase inicializado.
class TwoFactorService {
  TwoFactorService({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _instance => _functions ?? FirebaseFunctions.instance;

  /// Solicita o envio do código OTP para o e-mail do utilizador autenticado.
  ///
  /// Lança [FirebaseFunctionsException] em caso de erro no backend.
  Future<void> sendCode() async {
    await _instance
        .httpsCallable('twoFactor')
        .call<void>(<String, dynamic>{'action': 'send'});
  }

  /// Verifica o [code] de 6 dígitos informado pelo utilizador.
  ///
  /// Retorna `true` se o código for válido.
  /// Lança [FirebaseFunctionsException] em caso de erro (expirado, inválido, etc.).
  Future<bool> verifyCode(String code) async {
    final result = await _instance
        .httpsCallable('twoFactor')
        .call<Map<Object?, Object?>>({
          'action': 'verify',
          'code': code,
        });
    return result.data['verified'] == true;
  }

  /// Texto legível ao utilizador para erros comuns de 2FA.
  static String messageForError(Object error) {
    if (error is FirebaseFunctionsException) {
      final serverMsg = error.message?.trim();
      if (serverMsg != null &&
          serverMsg.isNotEmpty &&
          (error.code == 'failed-precondition' || error.code == 'internal')) {
        return serverMsg;
      }
      switch (error.code) {
        case 'not-found':
          return 'Código expirado ou não encontrado. Solicite um novo.';
        case 'invalid-argument':
          return 'Código incorreto. Tente novamente.';
        case 'resource-exhausted':
          return 'Muitas tentativas incorretas. Solicite um novo código.';
        case 'unauthenticated':
          return 'Sessão expirada. Faça login novamente.';
        case 'failed-precondition':
          return 'Conta sem e-mail — não é possível enviar o código.';
        case 'internal':
          return 'Erro no servidor. Tente novamente em instantes.';
        default:
          return 'Erro na verificação. Tente novamente.';
      }
    }
    return 'Não foi possível verificar o código agora.';
  }
}
