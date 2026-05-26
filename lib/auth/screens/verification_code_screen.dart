// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

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

/// Detecta colagem de vários dígitos antes do limite de 1 caractere por campo.
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

/// Tela de verificação de código no formato 2FA.
///
/// O usuário recebe um código de 6 dígitos no e-mail e deve inserir
/// em campos separados (estilo 2FA). Inclui timer para reenvio do código.
class VerificationCodeScreen extends StatefulWidget {
  const VerificationCodeScreen({
    super.key,
    required this.email,
  });

  /// E-mail para o qual o código foi enviado.
  final String email;

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  // 6 controllers para os 6 dígitos do código
  final List<TextEditingController> _digitControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _digitFocusNodes = List.generate(6, (_) => FocusNode());

  late final TapGestureRecognizer _resendRecognizer;

  bool _isVerifying = false;
  bool _isResending = false;
  final _passwordResetService = PasswordResetService();

  // Timer para o botão "Solicitar novamente"
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

  /// Obtém o código completo dos 6 campos.
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
    if (value.length > 1) {
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _digitFocusNodes[index + 1].requestFocus();
    }
    // Se preencheu todos os 6 dígitos, tenta verificar automaticamente
    if (_code.length == 6) {
      _onVerifyCode();
    }
  }

  /// Valida o código com o Firebase e navega para a tela de definir senha.
  Future<void> _onVerifyCode() async {
    if (_isVerifying) return;

    final code = _code;
    if (code.length != 6) {
      _showSnack('Informe os 6 dígitos do código.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final sessionToken = await _passwordResetService.verifyCode(
        email: widget.email.trim().toLowerCase(),
        code: code,
      );

      if (!mounted) return;

      // Código válido! Navega para a tela de definir senha
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

  /// Solicita um novo código de recuperação.
  Future<void> _onResendCode() async {
    if (_isResending || _resendCountdown > 0) return;

    setState(() => _isResending = true);
    try {
      await _passwordResetService.sendCode(widget.email.trim().toLowerCase());

      if (!mounted) return;

      _showSnack('Novo código enviado! Verifique seu e-mail.');
      _startResendTimer();

      // Limpa os campos
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
                        // Botão de voltar
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
                                // 6 campos individuais para o código (estilo 2FA)
                                _buildDigitRow(theme, colorScheme),
                                const SizedBox(height: 28),
                                // Botão de verificar
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
                                // Botão de reenviar código
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
