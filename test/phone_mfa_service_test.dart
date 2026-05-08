import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/auth/services/phone_mfa_service.dart';

void main() {
  group('PhoneMfaService', () {
    test('brazilDigitsToE164 formata 11 dígitos com +55', () {
      expect(
        PhoneMfaService.brazilDigitsToE164('19988887777'),
        '+5519988887777',
      );
    });

    test('brazilDigitsToE164 ignora não dígitos na entrada', () {
      expect(
        PhoneMfaService.brazilDigitsToE164('(19) 98888-7777'),
        '+5519988887777',
      );
    });

    test('brazilDigitsToE164 lança se não tiver 11 dígitos', () {
      expect(
        () => PhoneMfaService.brazilDigitsToE164('119999999'),
        throwsArgumentError,
      );
    });

    test('messageForError mapeia código FirebaseAuth', () {
      final msg = PhoneMfaService.messageForError(
        FirebaseAuthException(code: 'invalid-phone-number', message: null),
      );
      expect(msg.toLowerCase(), contains('telefone'));
    });
  });
}
