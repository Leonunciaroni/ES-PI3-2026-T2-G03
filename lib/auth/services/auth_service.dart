import 'package:firebase_auth/firebase_auth.dart';

/// Camada mínima para centralizar chamadas de autenticação e mensagens de erro.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  FirebaseAuth get _instance => _auth ?? FirebaseAuth.instance;

  Future<void> signIn({required String email, required String password}) async {
    await _instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    await _instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static String messageForError(Object error) {
    if (error is FirebaseException && error.code == 'no-app') {
      return 'Firebase não está configurado para esta plataforma.';
    }

    if (error is FirebaseAuthException) {
      if (_codeImpliesProjectConfiguration(error.code)) {
        return 'Configuração Firebase incompleta para Android (SHA/API).';
      }
      if (error.code == 'internal-error' &&
          _messageImpliesConfigurationNotFound(error)) {
        return 'Configuração Firebase incompleta para Android (SHA/API).';
      }
      switch (error.code) {
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'E-mail ou senha inválidos.';
        case 'email-already-in-use':
          return 'Este e-mail já está em uso.';
        case 'weak-password':
          return 'A senha é fraca demais.';
        case 'too-many-requests':
          return 'Muitas tentativas. Tente novamente em instantes.';
        case 'network-request-failed':
          return 'Sem conexão com a internet.';
        case 'internal-error':
          return 'Erro interno do Firebase. Verifique a configuração do projeto.';
        default:
          return 'Falha na autenticação. Tente novamente.';
      }
    }
    return 'Não foi possível concluir a operação agora.';
  }
}

/// Códigos [FirebaseAuth] que apontam para projeto / app / chave mal configurados
/// (preferível a inspecionar texto livre).
bool _codeImpliesProjectConfiguration(String code) {
  switch (code) {
    case 'invalid-api-key':
    case 'app-not-authorized':
      return true;
    default:
      return false;
  }
}

/// Alguns SDKs embutem `CONFIGURATION_NOT_FOUND` só em [FirebaseAuthException.message]
/// (ex.: `internal-error`).
bool _messageImpliesConfigurationNotFound(FirebaseAuthException error) {
  final String text = (error.message ?? error.toString()).toUpperCase();
  return text.contains('CONFIGURATION_NOT_FOUND');
}
