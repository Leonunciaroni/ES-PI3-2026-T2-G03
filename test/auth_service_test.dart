import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_iii/services/auth_service.dart';

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
    test('user-not-found', () {
      expect(
        AuthService.messageForError(
          FirebaseAuthException(code: 'user-not-found', message: null),
        ),
        'E-mail ou senha inválidos.',
      );
    });
  });
}
