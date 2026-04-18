import 'dart:math' show min;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Verificação em duas etapas: entrada do código, sucesso e falha (mesmo layout base).
///
/// Protótipo sem API — código **123456** resulta em sucesso; qualquer outro código de 6
/// dígitos mostra falha. A validação real deve ser feita no backend (sem segredos no app).
///
/// **Navegação após sucesso:** após ~2,4s, chama [Navigator.pop] apenas se
/// [Navigator.canPop] for verdadeiro. Se esta tela for o `home` do [MaterialApp],
/// não há rota para remover — o texto “Redirecionando…” é só informativo. O preview
/// em `main_two_factor_preview.dart` empilha esta rota para permitir o `pop`.
class TwoFactorVerificationScreen extends StatefulWidget {
  const TwoFactorVerificationScreen({super.key});

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

  _TwoFactorStep _step = _TwoFactorStep.input;

  @override
  void initState() {
    super.initState();
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

  void _onValidate() {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe os 6 dígitos do código.')),
      );
      return;
    }

    setState(() {
      _step = _code == '123456' ? _TwoFactorStep.success : _TwoFactorStep.failure;
    });

    if (_step == _TwoFactorStep.success) {
      Future<void>.delayed(const Duration(milliseconds: 2400), () {
        if (!mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  void _backToInput() {
    for (final c in _digitControllers) {
      c.clear();
    }
    setState(() => _step = _TwoFactorStep.input);
    _digitFocusNodes[0].requestFocus();
  }

  void _onResendTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Protótipo: reenvio de código será feito no backend.'),
      ),
    );
  }

  OutlineInputBorder _digitBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/mescla_logo.png',
        height: 88,
        fit: BoxFit.contain,
      ),
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
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _OtpPasteFormatter(_applyDigitsFromPaste),
                LengthLimitingTextInputFormatter(1),
              ],
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.searchFieldFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: _digitBorder(AppColors.fieldBorder),
                focusedBorder: _digitBorder(colorScheme.primary),
                border: _digitBorder(AppColors.fieldBorder),
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
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(30),
      color: Colors.white,
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
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Para garantir sua segurança você deve validar primeiro o seu acesso antes de utilizar o sistema',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            _buildDigitRow(theme, colorScheme),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _onValidate,
              style: FilledButton.styleFrom(
                elevation: 4,
                shadowColor: AppColors.primaryShadow(colorScheme),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
                backgroundColor: colorScheme.primary,
              ),
              child: const Text(
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
                  color: AppColors.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'Não recebeu seu código? '),
                  TextSpan(
                    text: 'Clique aqui para enviar novamente',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.linkAccent,
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
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(30),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFE8E9ED),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Verificação concluída!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Redirecionando para Dashboard...',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.linkAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureCard(ThemeData theme) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(30),
      color: Colors.white,
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
                    color: AppColors.linkAccent,
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.gradientTop,
                AppColors.gradientBottom,
              ],
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
                        _buildLogo(),
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
                            color: AppColors.textSecondary.withValues(alpha: 0.85),
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
