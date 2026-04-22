import 'package:firebase_auth/firebase_auth.dart';

/// Centraliza mensagens de erro de autenticação para UI consistente.
class AuthService {
  AuthService._();

  /// Erros de [signIn] / [createUserWithEmailAndPassword].
  static String messageForError(Object error) {
    if (error is FirebaseException && error.code == 'no-app') {
      return 'Firebase não está configurado para esta plataforma.';
    }
    if (error is FirebaseAuthException) {
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
        default:
          return 'Falha na autenticação. Tente novamente.';
      }
    }
    return 'Não foi possível concluir a operação agora.';
  }

  /// Erros de [sendPasswordResetEmail] — evita mensagens de login em contexto de reset.
  static String messageForPasswordResetError(Object error) {
    if (error is FirebaseException && error.code == 'no-app') {
      return messageForError(error);
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'user-not-found':
          return 'Se existir uma conta para este e-mail, receberá instruções em breve.';
        case 'too-many-requests':
        case 'network-request-failed':
          return messageForError(error);
        default:
          return 'Não foi possível enviar agora. Tente novamente.';
      }
    }
    return 'Erro inesperado ao enviar instruções.';
  }
}
