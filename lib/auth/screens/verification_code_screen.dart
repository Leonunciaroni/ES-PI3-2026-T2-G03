// ============================================================
// ARQUIVO: verification_code_screen.dart
// Autor principal: Pedro Henrique Contardi Soler - 25005592
// Contribuição: Miguel Fernandes Costacurta — RA: 25003110
// ============================================================
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ MIGUEL — O QUE VOCÊ FEZ NESTE FLUXO                                      │
// │                                                                          │
// │ ETAPA 2/3 do reset de senha (esta tela):                                 │
// │   • 6 campos para digitar o OTP recebido no e-mail                       │
// │   • Chama verifyCode → recebe sessionToken                               │
// │   • Navega para ResetPasswordScreen com esse token                       │
// │                                                                          │
// │ sessionToken = prova temporária de que o usuário validou o e-mail.       │
// │ Sem ele, ninguém pode trocar a senha na etapa 3.                         │
// │                                                                          │
// │ CAMINHO DE ESTUDO:                                                       │
// │   1. _onVerifyCode() e _onResendCode() neste arquivo                     │
// │   2. password_reset_service.dart → verifyCode()                          │
// │   3. passwordReset.ts → handleVerify()                                   │
// │   4. passwordResetRepository.ts → verifyResetCode()                      │
// └──────────────────────────────────────────────────────────────────────────┘

import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../services/password_reset_service.dart';
import '../widgets/otp_delivery_banner.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import 'reset_password_screen.dart';

/// Detecta colagem de vários dígitos (ex.: copiar "482910" de uma vez).
class _OtpPasteFormatter extends TextInputFormatter {
  _OtpPasteFormatter(this.onMultiDigit);
  final void Function(String digits) onMultiDigit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMultiDigit(digits);
      });
      return oldValue;
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// Tela 2 do reset: usuário digita o OTP de 6 dígitos.
class VerificationCodeScreen extends StatefulWidget {
  const VerificationCodeScreen({
    super.key,
    required this.email,
  });

  /// E-mail informado na RecoverPasswordScreen — usado na verificação no servidor.
  final String email;

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  // Um controller e um FocusNode por dígito (6 campos).
  final List<TextEditingController> _digitControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _digitFocusNodes = List.generate(6, (_) => FocusNode());

  late final TapGestureRecognizer _resendRecognizer;

  bool _isVerifying = false;
  bool _isResending = false;
  final _passwordResetService = PasswordResetService();

  // Countdown de 60s antes de permitir reenviar o código.
  int _resendCountdown = 60;
  Timer? _resendTimer;

  static const _footerTrust = 'PROJETO INTEGRADOR III - GRUPO 3';

  @override
  void initState() {
    super.initState();
    _resendRecognizer = TapGestureRecognizer()..onTap = _onResendCode;
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendRecognizer.dispose();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _digitFocusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Junta os 6 campos numa String só (ex.: "482910").
  String get _code => _digitControllers.map((c) => c.text).join();

  void _applyDigitsFromPaste(String raw) {
    if (!mounted) return;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final take = digits.length > 6 ? digits.substring(0, 6) : digits;
    for (var i = 0; i < 6; i++) {
      _digitControllers[i].text = i < take.length ? take[i] : '';
    }
    setState(() {});
    final focusIndex = min(take.length, 5);
    _digitFocusNodes[focusIndex].requestFocus();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) return;
    if (value.isNotEmpty && index < 5) {
      _digitFocusNodes[index + 1].requestFocus();
    }
    // Auto-verifica quando completar 6 dígitos.
    if (_code.length == 6) {
      _onVerifyCode();
    }
  }

  // [MIGUEL - ESTUDE] Valida OTP e obtém sessionToken para a próxima tela.
  Future<void> _onVerifyCode() async {
    if (_isVerifying) return;

    final code = _code;
    if (code.length != 6) {
      _showSnack('Informe os 6 dígitos do código.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      // Cloud Function passwordReset action: "verify"
      // → confere hash no Firestore → devolve sessionToken se OK.
      final sessionToken = await _passwordResetService.verifyCode(
        email: widget.email.trim().toLowerCase(),
        code: code,
      );

      if (!mounted) return;

      // pushReplacement: troca esta tela pela de nova senha (não dá voltar).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => ResetPasswordScreen(sessionToken: sessionToken),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      _showSnack(PasswordResetService.messageForError(e));
    } catch (e) {
      _showSnack('Erro ao verificar código. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  // Reenvia OTP (mesma action "send" da RecoverPasswordScreen).
  Future<void> _onResendCode() async {
    if (_isResending || _resendCountdown > 0) return;

    setState(() => _isResending = true);
    try {
      await _passwordResetService.sendCode(widget.email.trim().toLowerCase());

      if (!mounted) return;

      _showSnack('Novo código enviado! Verifique seu e-mail.');
      _startResendTimer();

      for (final c in _digitControllers) {
        c.clear();
      }
      _digitFocusNodes[0].requestFocus();
    } on FirebaseFunctionsException catch (e) {
      _showSnack(PasswordResetService.messageForError(e));
    } catch (e) {
      _showSnack('Erro ao reenviar código. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  OutlineInputBorder _digitBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
  }

  Widget _buildDigitRow(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 46,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey != LogicalKeyboardKey.backspace) {
                return KeyEventResult.ignored;
              }
              if (_digitControllers[index].text.isNotEmpty) {
                return KeyEventResult.ignored;
              }
              if (index == 0) {
                return KeyEventResult.ignored;
              }
              _digitFocusNodes[index - 1].requestFocus();
              final prev = _digitControllers[index - 1].text;
              if (prev.isNotEmpty) {
                _digitControllers[index - 1].text =
                    prev.substring(0, prev.length - 1);
              }
              return KeyEventResult.handled;
            },
            child: TextField(
              controller: _digitControllers[index],
              focusNode: _digitFocusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _OtpPasteFormatter(_applyDigitsFromPaste),
                LengthLimitingTextInputFormatter(1),
              ],
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.searchFieldFillForTheme(theme),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: _digitBorder(AppColors.cardDivider(theme)),
                focusedBorder: _digitBorder(colorScheme.primary),
                border: _digitBorder(AppColors.cardDivider(theme)),
              ),
              onChanged: (v) => _onDigitChanged(index, v),
              onSubmitted: (_) {
                if (index < 5) {
                  _digitFocusNodes[index + 1].requestFocus();
                } else {
                  _onVerifyCode();
                }
              },
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gradientStops = AppColors.shellGradientColors(theme.brightness);

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: AppColors.textSecondary,
                            tooltip: 'Voltar',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const MesclaAuthHeaderLogo(),
                        const SizedBox(height: 28),
                        Material(
                          elevation: theme.brightness == Brightness.dark ? 8 : 6,
                          shadowColor: Colors.black.withValues(
                            alpha: theme.brightness == Brightness.dark ? 0.35 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          color: AppColors.themeCardSurface(theme),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Código de verificação',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                OtpDeliveryBanner(
                                  channel: OtpDeliveryChannel.email,
                                  destinationDetail: widget.email.trim(),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Digite abaixo o código de 6 dígitos recebido neste e-mail.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.secondaryLabel(theme),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                _buildDigitRow(theme, colorScheme),
                                const SizedBox(height: 28),
                                FilledButton(
                                  onPressed: _isVerifying ? null : _onVerifyCode,
                                  style: FilledButton.styleFrom(
                                    elevation: 4,
                                    shadowColor: AppColors.primaryShadow(
                                      colorScheme,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: const StadiumBorder(),
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                  ),
                                  child: _isVerifying
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : const Text(
                                          'Verificar código',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 20),
                                if (_resendCountdown > 0)
                                  Text(
                                    'Solicitar novamente em $_resendCountdown segundos',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.secondaryLabel(theme),
                                    ),
                                  )
                                else
                                  Text.rich(
                                    TextSpan(
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: AppColors.secondaryLabel(theme),
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Não recebeu seu código? ',
                                        ),
                                        TextSpan(
                                          text:
                                              'Clique aqui para enviar novamente',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          recognizer: _resendRecognizer,
                                          semanticsLabel:
                                              'Reenviar código de verificação',
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          _footerTrust,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.secondaryLabel(theme)
                                .withValues(alpha: 0.9),
                            letterSpacing: 0.6,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
