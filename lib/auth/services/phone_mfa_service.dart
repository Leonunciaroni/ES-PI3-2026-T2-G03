// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Serviço de MFA por SMS via Firebase Authentication (Phone Verification).
// Encapsula [verifyPhoneNumber], construção de [PhoneAuthCredential] e
// [User.reauthenticateWithCredential] (login) ou [User.linkWithCredential] (associar telefone).

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Indica se o SMS serve para validar o segundo passo do login ou para ligar o número ao utilizador.
enum PhoneSmsIntent {
  /// Depois do e-mail/senha: prova posse do telefone sem alterar o UID da sessão.
  loginSecondFactor,

  /// Nas definições / primeiro login: associa o número ao [User] atual no Firebase Auth.
  enrollLinkPhone,
}

/// Pedidos de SMS e confirmação do código de 6 dígitos para MFA por telefone.
///
/// Em testes pode injetar-se um [FirebaseAuth] falso; na app usa-se [FirebaseAuth.instance].
class PhoneMfaService {
  PhoneMfaService({FirebaseAuth? auth}) : _authOverride = auth;

  /// Permite substituir o Auth em testes unitários (opcional).
  final FirebaseAuth? _authOverride;

  /// Resolve sempre o cliente Auth real ou o mock injetado.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Identificador da sessão de verificação atual (devolvido pelo Firebase no envio do SMS).
  String? _verificationId;

  /// Token Android para "reenviar" sem novo fluxo completo (pode ser null noutras plataformas).
  int? _resendToken;

  /// Momento do último pedido bem-sucedido de SMS (cooldown entre envios no cliente).
  DateTime? _lastSendUtc;

  /// Intervalo mínimo entre pedidos de novo SMS no mesmo ecrã (complementa quotas do Firebase).
  static const int cooldownSeconds = 60;

  /// Devolve `true` se já passou o [cooldownSeconds] desde o último envio.
  bool get canRequestSmsNow {
    if (_lastSendUtc == null) {
      return true;
    }
    final elapsed = DateTime.now().toUtc().difference(_lastSendUtc!).inSeconds;
    return elapsed >= cooldownSeconds;
  }

  /// Segundos restantes até poder voltar a pedir SMS (útil para texto no botão "Reenviar").
  int get secondsUntilCanResend {
    if (_lastSendUtc == null) {
      return 0;
    }
    final elapsed = DateTime.now().toUtc().difference(_lastSendUtc!).inSeconds;
    final left = cooldownSeconds - elapsed;
    return left < 0 ? 0 : left;
  }

  /// Converte 11 dígitos de celular BR (somente números) para formato E.164 exigido pelo Firebase.
  ///
  /// Exemplo: `19988887777` → `+5519988887777`.
  static String brazilDigitsToE164(String elevenDigits) {
    final only = elevenDigits.replaceAll(RegExp(r'\D'), '');
    if (only.length != 11) {
      throw ArgumentError(
        'O telefone deve ter 11 dígitos (DDD + nove dígitos).',
      );
    }
    return '+55$only';
  }

  /// Mensagens amigáveis para erros comuns do fluxo de telefone.
  static String messageForError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return 'Número de telefone inválido. Verifique DDD e dígitos.';
        case 'too-many-requests':
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : 'Muitas tentativas. Aguarde alguns minutos ou tente outro meio.';
        case 'quota-exceeded':
          return 'Limite de SMS atingido. Tente mais tarde ou use verificação por e-mail.';
        case 'operation-not-allowed':
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : 'Telefone não está ativado no projeto Firebase.';
        case 'credential-already-in-use':
          return 'Este número já está associado a outra conta.';
        case 'provider-already-linked':
          return 'Este utilizador já tem um telefone associado.';
        case 'invalid-verification-code':
          return 'Código SMS incorreto.';
        case 'session-expired':
          return 'O código expirou. Solicite um novo SMS.';
        default:
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : 'Erro na verificação por telefone.';
      }
    }
    if (error is ArgumentError) {
      return error.message ?? 'Dados inválidos.';
    }
    return 'Não foi possível concluir a verificação por SMS.';
  }

  /// Aplica o credential conforme o intent (login MFA ou associação).
  Future<void> _applyCredential(
    PhoneAuthCredential credential,
    PhoneSmsIntent intent,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sessão não encontrada. Faça login novamente.',
      );
    }
    switch (intent) {
      case PhoneSmsIntent.loginSecondFactor:
        await user.reauthenticateWithCredential(credential);
      case PhoneSmsIntent.enrollLinkPhone:
        await user.linkWithCredential(credential);
    }
  }

  /// Dispara o envio do SMS para [phoneE164] e guarda [_verificationId] / [_resendToken].
  ///
  /// [onAutoVerified]: em alguns Android o SMS é lido automaticamente e o Firebase completa aqui.
  Future<void> requestSmsCode({
    required String phoneE164,
    required PhoneSmsIntent intent,
    bool forceResend = false,
    void Function()? onAutoVerified,
  }) async {
    if (kIsWeb) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed',
        message:
            'Verificação por SMS neste projeto está preparada para Android/iOS. '
            'Na web seria necessário reCAPTCHA (configuração extra).',
      );
    }
    if (!canRequestSmsNow) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message:
            'Aguarde ${secondsUntilCanResend}s antes de pedir outro SMS.',
      );
    }

    final completer = Completer<void>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 120),
      forceResendingToken: forceResend ? _resendToken : null,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _applyCredential(credential, intent);
          _lastSendUtc ??= DateTime.now().toUtc();
          onAutoVerified?.call();
          if (!completer.isCompleted) {
            completer.complete();
          }
        } catch (e) {
          final fe = e is FirebaseAuthException
              ? e
              : FirebaseAuthException(
                  code: 'internal-error',
                  message: e.toString(),
                );
          if (!completer.isCompleted) {
            completer.completeError(fe);
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        _lastSendUtc = DateTime.now().toUtc();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );

    await completer.future;
  }

  /// Confirma o código de 6 dígitos digitado pelo utilizador (fluxo manual).
  Future<void> submitSmsCode({
    required String smsCode,
    required PhoneSmsIntent intent,
  }) async {
    final trimmed = smsCode.trim();
    if (trimmed.length != 6 || !RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'Informe os 6 dígitos enviados por SMS.',
      );
    }
    final vid = _verificationId;
    if (vid == null || vid.isEmpty) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'Peça um novo código SMS antes de validar.',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: vid,
      smsCode: trimmed,
    );
    await _applyCredential(credential, intent);
  }

  /// Novo pedido de SMS mantendo o mesmo número (usa [forceResendingToken] no Android).
  Future<void> resendSms({
    required String phoneE164,
    required PhoneSmsIntent intent,
    void Function()? onAutoVerified,
  }) async {
    await requestSmsCode(
      phoneE164: phoneE164,
      intent: intent,
      forceResend: true,
      onAutoVerified: onAutoVerified,
    );
  }
}
