// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Associa o número de telefone ao utilizador atual no Firebase Auth através de
// SMS ([PhoneSmsIntent.enrollLinkPhone]). Opcionalmente, após associar, abre o
// segundo passo de MFA por SMS no login quando [continueToLoginOtp] é true.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../services/phone_mfa_service.dart';
import '../services/user_firestore_service.dart';
import 'phone_sms_verification_screen.dart';

/// Primeiro pede o número mascarado; depois abre o ecrã de código SMS.
class LinkPhoneForMfaScreen extends StatefulWidget {
  const LinkPhoneForMfaScreen({
    super.key,
    required this.continueToLoginOtp,
    this.showDashboardRedirectAfterSmsVerify = false,
  });

  /// Se true, após ligar o telefone envia novo SMS para completar o MFA do login atual.
  final bool continueToLoginOtp;

  /// Fluxo de cadastro: após validar o SMS mostra «Redirecionando para Dashboard…» antes de fechar.
  final bool showDashboardRedirectAfterSmsVerify;

  @override
  State<LinkPhoneForMfaScreen> createState() => _LinkPhoneForMfaScreenState();
}

class _LinkPhoneForMfaScreenState extends State<LinkPhoneForMfaScreen> {
  final _phoneController = TextEditingController();
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool _loadingDigits = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _prefillPhoneFromProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Copia o telefone do Firestore (cadastro) para o campo, já como máscara BR.
  Future<void> _prefillPhoneFromProfile() async {
    final digits = await UserFirestoreService.fetchProfilePhoneDigits();
    if (!mounted) {
      return;
    }
    if (digits != null && digits.length == 11) {
      final masked = _phoneFormatter.maskText(digits);
      _phoneController.text = masked;
    }
    setState(() => _loadingDigits = false);
  }

  bool _isValidBrazilMobile(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 11) {
      return false;
    }
    return digits[2] == '9';
  }

  /// Envia o primeiro SMS de associação e navega para o OTP no mesmo fluxo.
  Future<void> _onContinue() async {
    if (_sending) {
      return;
    }
    final phone = _phoneController.text.trim();
    if (!_isValidBrazilMobile(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe um celular válido (DDD + 9 dígitos).',
          ),
        ),
      );
      return;
    }

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final e164 = PhoneMfaService.brazilDigitsToE164(digits);
    final svc = PhoneMfaService();

    setState(() => _sending = true);
    try {
      await svc.requestSmsCode(
        phoneE164: e164,
        intent: PhoneSmsIntent.enrollLinkPhone,
      );
      if (!mounted) {
        return;
      }
      final enrolled = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PhoneSmsVerificationScreen(
            phoneMfaService: svc,
            phoneE164: e164,
            intent: PhoneSmsIntent.enrollLinkPhone,
            smsAlreadyRequested: true,
            postSuccessTitle: widget.showDashboardRedirectAfterSmsVerify
                ? 'Telefone confirmado!'
                : null,
            postSuccessStatusLine: widget.showDashboardRedirectAfterSmsVerify
                ? 'Redirecionando para Dashboard...'
                : null,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      if (enrolled == true && widget.continueToLoginOtp) {
        await _openLoginSmsAfterLink();
      } else if (enrolled == true) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PhoneMfaService.messageForError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  /// Depois de [linkWithCredential], o Auth expõe [User.phoneNumber] em E.164.
  Future<void> _openLoginSmsAfterLink() async {
    final user = FirebaseAuth.instance.currentUser;
    final pn = user?.phoneNumber;
    if (pn == null || pn.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telefone associado, mas não foi possível pedir o SMS de login.'),
        ),
      );
      await UserFirestoreService.signOut();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(false);
      return;
    }

    final loginSvc = PhoneMfaService();
    try {
      await loginSvc.requestSmsCode(
        phoneE164: pn,
        intent: PhoneSmsIntent.loginSecondFactor,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PhoneSmsVerificationScreen(
            phoneMfaService: loginSvc,
            phoneE164: pn,
            intent: PhoneSmsIntent.loginSecondFactor,
            smsAlreadyRequested: true,
            replaceStackWithDashboard: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PhoneMfaService.messageForError(e))),
      );
      await UserFirestoreService.signOut();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(false);
    }
  }

  OutlineInputBorder _stadiumBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gradientStops = AppColors.shellGradientColors(theme.brightness);
    final fieldStroke = theme.brightness == Brightness.light
        ? AppColors.fieldBorder
        : colorScheme.outline;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.shellOverlayStyle(theme.brightness),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientStops,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () async {
                        // Só encerra a sessão ao cancelar durante o MFA do login;
                        // em perfil / primeiro acesso o utilizador volta sem perder a conta.
                        if (widget.continueToLoginOtp) {
                          await UserFirestoreService.signOut();
                        }
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop(false);
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.textSecondary,
                      tooltip: 'Voltar',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const MesclaAuthHeaderLogo(),
                  const SizedBox(height: 24),
                  Text(
                    'Associar telefone',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Este número será usado para enviar o código SMS quando escolher MFA por telefone.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_loadingDigits)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_phoneFormatter],
                      decoration: InputDecoration(
                        hintText: '(XX) 9XXXX-XXXX',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                        enabledBorder: _stadiumBorder(fieldStroke),
                        focusedBorder: _stadiumBorder(colorScheme.primary),
                        border: _stadiumBorder(fieldStroke),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _sending ? null : _onContinue,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                      child: _sending
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Text('Enviar código SMS'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
