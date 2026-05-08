import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/auth/services/auth_service.dart';

void main() {
  group('AuthService.messageForPasswordResetError', () {
    test('invalid-email', () {
      expect(
        AuthService.messageForPasswordResetError(
          FirebaseAuthException(code: 'invalid-email', message: 'bad'),
        ),
        'E-mail inválido.',
      );
    });

    test('user-not-found usa mensagem neutra', () {
      expect(
        AuthService.messageForPasswordResetError(
          FirebaseAuthException(code: 'user-not-found', message: null),
        ),
        contains('conta'),
      );
    });
  });

  group('AuthService.messageForError', () {
    test('no-app (FirebaseException)', () {
      final out = AuthService.messageForError(
        FirebaseException(
          plugin: 'core',
          code: 'no-app',
          message: 'No app',
        ),
      );
      expect(out, 'Firebase não está configurado para esta plataforma.');
    });

    test('invalid-api-key mapeado por código', () {
      final out = AuthService.messageForError(
        FirebaseAuthException(
          code: 'invalid-api-key',
          message: 'API key not valid',
        ),
      );
      expect(out, 'Configuração Firebase incompleta para Android (SHA/API).');
    });

    test('app-not-authorized mapeado por código', () {
      final out = AuthService.messageForError(
        FirebaseAuthException(
          code: 'app-not-authorized',
          message: 'App not authorized',
        ),
      );
      expect(out, 'Configuração Firebase incompleta para Android (SHA/API).');
    });

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
