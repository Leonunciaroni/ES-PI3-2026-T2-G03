import 'dart:math' show min;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dashboard/screens/dashboard_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../services/two_factor_service.dart';

/// Verificação em duas etapas: entrada do código, sucesso e falha.
///
/// O código OTP é validado via Firebase Function `twoFactor` com `action: verify`.
/// O envio (e reenvio) usa [TwoFactorService.sendCode].
///
/// **Navegação após sucesso:** após ~2,4s, se [replaceStackWithDashboard] for true, limpa a
/// pilha e abre [DashboardScreen]; senão, chama [onVerificationSuccess] se definido; senão,
/// [Navigator.pop] quando [Navigator.canPop] for verdadeiro (preview/testes).
class TwoFactorVerificationScreen extends StatefulWidget {
  const TwoFactorVerificationScreen({
    super.key,
    this.replaceStackWithDashboard = false,
    this.onVerificationSuccess,
    TwoFactorService? twoFactorService,
  }) : _twoFactorService = twoFactorService;

  /// Fluxo login → 2FA → dashboard.
  final bool replaceStackWithDashboard;

  /// Opcional: ação extra após sucesso (não usada quando [replaceStackWithDashboard] é true).
  final VoidCallback? onVerificationSuccess;

  final TwoFactorService? _twoFactorService;

  @override
  State<TwoFactorVerificationScreen> createState() =>
      _TwoFactorVerificationScreenState();
}

enum _TwoFactorStep { input, success, failure }

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

class _TwoFactorVerificationScreenState extends State<TwoFactorVerificationScreen> {
  static const _footerTrust = 'PROJETO INTEGRADOR III - GRUPO 3';
  static const _errorCircle = Color(0xFFD32F2F);

  final List<TextEditingController> _digitControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _digitFocusNodes = List.generate(6, (_) => FocusNode());

  late final TapGestureRecognizer _resendRecognizer;
  late final TwoFactorService _twoFactorService;

  _TwoFactorStep _step = _TwoFactorStep.input;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _twoFactorService = widget._twoFactorService ?? TwoFactorService();
    _resendRecognizer = TapGestureRecognizer()..onTap = _onResendTap;
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
    super.dispose();
  }

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
  }

  Future<void> _onValidate() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe os 6 dígitos do código.')),
      );
      return;
    }
    if (_isValidating) return;
    setState(() => _isValidating = true);

    try {
      await _twoFactorService.verifyCode(_code);
      if (!mounted) return;
      setState(() => _step = _TwoFactorStep.success);
      Future<void>.delayed(const Duration(milliseconds: 2400), () {
        if (!mounted) return;
        if (widget.replaceStackWithDashboard) {
          Navigator.of(context).pushAndRemoveUntil<void>(
            MaterialPageRoute<void>(
              builder: (_) => const DashboardScreen(),
            ),
            (route) => false,
          );
          return;
        }
        final onSuccess = widget.onVerificationSuccess;
        if (onSuccess != null) {
          onSuccess();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _step = _TwoFactorStep.failure);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TwoFactorService.messageForError(error))),
      );
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  void _backToInput() {
    for (final c in _digitControllers) {
      c.clear();
    }
    setState(() => _step = _TwoFactorStep.input);
    _digitFocusNodes[0].requestFocus();
  }

  Future<void> _onResendTap() async {
    try {
      await _twoFactorService.sendCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código reenviado para o seu e-mail.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TwoFactorService.messageForError(error)),
        ),
      );
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
                  _onValidate();
                }
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInputCard(ThemeData theme, ColorScheme colorScheme) {
    final shadowA = theme.brightness == Brightness.dark ? 0.35 : 0.08;
    return Material(
      elevation: theme.brightness == Brightness.dark ? 8 : 6,
      shadowColor: Colors.black.withValues(alpha: shadowA),
      borderRadius: BorderRadius.circular(30),
      color: AppColors.themeCardSurface(theme),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verificação de duas etapas',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Para garantir sua segurança você deve validar primeiro o seu acesso antes de utilizar o sistema',
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
              onPressed: _isValidating ? null : _onValidate,
              style: FilledButton.styleFrom(
                elevation: 4,
                shadowColor: AppColors.primaryShadow(colorScheme),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: _isValidating
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Text(
                      'Validar conta',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
                children: [
                  const TextSpan(text: 'Não recebeu seu código? '),
                  TextSpan(
                    text: 'Clique aqui para enviar novamente',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: _resendRecognizer,
                    semanticsLabel: 'Reenviar código de verificação',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final shadowA = theme.brightness == Brightness.dark ? 0.35 : 0.08;
    return Material(
      elevation: theme.brightness == Brightness.dark ? 8 : 6,
      shadowColor: Colors.black.withValues(alpha: shadowA),
      borderRadius: BorderRadius.circular(30),
      color: AppColors.themeCardSurface(theme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? colorScheme.surfaceContainerHighest
                    : const Color(0xFFE8E9ED),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 56,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Verificação concluída!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Redirecionando para Dashboard...',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final shadowA = theme.brightness == Brightness.dark ? 0.35 : 0.08;
    return Material(
      elevation: theme.brightness == Brightness.dark ? 8 : 6,
      shadowColor: Colors.black.withValues(alpha: shadowA),
      borderRadius: BorderRadius.circular(30),
      color: AppColors.themeCardSurface(theme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: _errorCircle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.priority_high_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Falha na verificação!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Solicitar código novamente',
              child: GestureDetector(
                onTap: _backToInput,
                child: Text(
                  'Solicitar código novamente',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const MesclaAuthHeaderLogo(),
                        const SizedBox(height: 28),
                        switch (_step) {
                          _TwoFactorStep.input =>
                            _buildInputCard(theme, colorScheme),
                          _TwoFactorStep.success => _buildSuccessCard(theme),
                          _TwoFactorStep.failure => _buildFailureCard(theme),
                        },
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
