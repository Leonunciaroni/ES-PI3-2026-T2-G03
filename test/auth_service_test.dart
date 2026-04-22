import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/services/auth_service.dart';

void main() {
  group('AuthService.messageForError', () {
    test('internal-error com detalhe CONFIGURATION_NOT_FOUND', () {
      final out = AuthService.messageForError(
        FirebaseAuthException(
          code: 'internal-error',
          message: 'Network error. CONFIGURATION_NOT_FOUND',
        ),
      );
      expect(out, 'Configuração Firebase incompleta para Android (SHA/API).');
    });

    test('internal-error genérico', () {
      final out = AuthService.messageForError(
        FirebaseAuthException(
          code: 'internal-error',
          message: 'Generic failure',
        ),
      );
      expect(
        out,
        'Erro interno do Firebase. Verifique a configuração do projeto.',
      );
    });

    test('user-not-found', () {
      final out = AuthService.messageForError(
        FirebaseAuthException(code: 'user-not-found', message: null),
      );
      expect(out, 'E-mail ou senha inválidos.');
    });

    test('código desconhecido cai no default', () {
      final out = AuthService.messageForError(
        FirebaseAuthException(code: 'unknown-test-code', message: 'x'),
      );
      expect(out, 'Falha na autenticação. Tente novamente.');
    });

    test('erro que não é Firebase', () {
      final out = AuthService.messageForError(StateError('fail'));
      expect(out, 'Não foi possível concluir a operação agora.');
    });
  });
}
