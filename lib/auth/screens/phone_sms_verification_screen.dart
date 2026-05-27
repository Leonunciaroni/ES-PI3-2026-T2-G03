// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Confirmação do código SMS do Firebase Phone Auth para MFA (login) ou para
// associar o telefone ao usuário ([PhoneSmsIntent]). Reutiliza o layout dos
// 6 dígitos semelhante ao OTP por e-mail.

import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../catalog/services/startup_catalog_list_cache.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../services/phone_mfa_service.dart';
import '../services/session_persistence_service.dart';
import '../widgets/otp_delivery_banner.dart';

/// Formata eventos de tecla para apagar dígitos OTP com retrocesso entre campos.
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

/// Validação por SMS após [PhoneMfaService.requestSmsCode] ou abre o pedido inicial se [smsAlreadyRequested] for false.
class PhoneSmsVerificationScreen extends StatefulWidget {
  const PhoneSmsVerificationScreen({
    super.key,
    this.phoneMfaService,
    required this.phoneE164,
    required this.intent,
    this.smsAlreadyRequested = false,
    this.replaceStackWithDashboard = false,
    this.onVerificationSuccess,
    this.postSuccessTitle,
    this.postSuccessStatusLine,
    this.postSuccessHold = const Duration(milliseconds: 2400),
  });

  /// Serviço injetável em testes; quando null usa instância nova.
  final PhoneMfaService? phoneMfaService;

  /// Número em E.164 usado no pedido de SMS (reenvio usa o mesmo).
  final String phoneE164;

  /// Define se o código confirma login ou associa telefone ao perfil Auth.
  final PhoneSmsIntent intent;

  /// Quando true, o primeiro SMS já foi pedido antes desta tela (ex.: login).
  final bool smsAlreadyRequested;

  /// Igual ao fluxo e-mail: após sucesso substitui a pilha pelo dashboard.
  final bool replaceStackWithDashboard;

  /// Alternativa ao dashboard quando [replaceStackWithDashboard] é false.
  final VoidCallback? onVerificationSuccess;

  /// Se não null, após OTP válido mostra cartão de sucesso com este texto antes de concluir.
  final String? postSuccessStatusLine;

  /// Título do cartão intermédio (omissão: "Telefone confirmado!").
  final String? postSuccessTitle;

  /// Tempo de exibição do cartão antes de fechar ou ir ao dashboard.
  final Duration postSuccessHold;

  @override
  State<PhoneSmsVerificationScreen> createState() =>
      _PhoneSmsVerificationScreenState();
}

class _PhoneSmsVerificationScreenState extends State<PhoneSmsVerificationScreen> {
  static const _footerTrust = 'PROJETO INTEGRADOR III - GRUPO 3';

  final List<TextEditingController> _digitControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _digitFocusNodes = List.generate(6, (_) => FocusNode());

  late final PhoneMfaService _svc;

  Timer? _cooldownTicker;
  Timer? _postSuccessHoldTimer;
  int _cooldownLeft = 0;

  bool _isValidating = false;
  bool _initialSendFailed = false;
  bool _showPostSuccessUi = false;

  bool get _holdsPostSuccessUi {
    final line = widget.postSuccessStatusLine?.trim();
    return line != null && line.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _svc = widget.phoneMfaService ?? PhoneMfaService();
    if (!widget.smsAlreadyRequested) {
      _sendInitialSms();
    } else {
      _startCooldownTicker();
    }
  }

  @override
  void dispose() {
    _postSuccessHoldTimer?.cancel();
    _cooldownTicker?.cancel();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _digitFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Primeiro envio quando esta tela é responsável por disparar o SMS.
  Future<void> _sendInitialSms() async {
    try {
      await _svc.requestSmsCode(
        phoneE164: widget.phoneE164,
        intent: widget.intent,
        onAutoVerified: _onAutoVerifiedFromDevice,
      );
      if (!mounted) {
        return;
      }
      _startCooldownTicker();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _initialSendFailed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PhoneMfaService.messageForError(e))),
      );
    }
  }

  /// Alguns Android confirmam o SMS sem digitar — mesmo fluxo de sucesso manual.
  Future<void> _onAutoVerifiedFromDevice() async {
    if (!mounted) {
      return;
    }
    await _afterPhoneVerified();
  }

  String get _code => _digitControllers.map((c) => c.text).join();

  /// Cola vários dígitos de uma vez na linha OTP.
  void _applyDigitsFromPaste(String raw) {
    if (!mounted) {
      return;
    }
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return;
    }
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

  /// Atualiza o texto do botão de reenvio enquanto corre o cooldown local.
  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    setState(() => _cooldownLeft = _svc.secondsUntilCanResend);
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final s = _svc.secondsUntilCanResend;
      setState(() => _cooldownLeft = s);
      if (s <= 0) {
        _cooldownTicker?.cancel();
      }
    });
  }

  Future<void> _afterPhoneVerified() async {
    if (!_holdsPostSuccessUi) {
      await _finishSuccessNavigation();
      return;
    }
    setState(() => _showPostSuccessUi = true);
    _postSuccessHoldTimer?.cancel();
    _postSuccessHoldTimer = Timer(widget.postSuccessHold, () async {
      if (!mounted) {
        return;
      }
      await _finishSuccessNavigation();
    });
  }

  Future<void> _finishSuccessNavigation() async {
    if (widget.replaceStackWithDashboard) {
      StartupCatalogListCache.instance.clear();
      await SessionPersistenceService.recordSessionAfterLogin();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => const DashboardScreen(),
        ),
        (route) => false,
      );
      return;
    }
    final cb = widget.onVerificationSuccess;
    if (cb != null) {
      cb();
      return;
    }
    if (widget.intent == PhoneSmsIntent.enrollLinkPhone) {
      Navigator.of(context).pop(true);
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onValidate() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe os 6 dígitos do código SMS.')),
      );
      return;
    }
    if (_isValidating) {
      return;
    }
    setState(() => _isValidating = true);

    try {
      await _svc.submitSmsCode(smsCode: _code, intent: widget.intent);
      if (!mounted) {
        return;
      }
      await _afterPhoneVerified();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PhoneMfaService.messageForError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  Future<void> _onResendTap() async {
    if (!_svc.canRequestSmsNow) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aguarde ${_svc.secondsUntilCanResend}s para reenviar o SMS.',
          ),
        ),
      );
      return;
    }
    try {
      await _svc.resendSms(
        phoneE164: widget.phoneE164,
        intent: widget.intent,
        onAutoVerified: _onAutoVerifiedFromDevice,
      );
      if (!mounted) {
        return;
      }
      _startCooldownTicker();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Novo SMS enviado.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PhoneMfaService.messageForError(e))),
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
                _digitControllers[index - 1].text = prev.substring(
                  0,
                  prev.length - 1,
                );
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

  Widget _buildPostSuccessCard(ThemeData theme, ColorScheme colorScheme) {
    final shadowA = theme.brightness == Brightness.dark ? 0.35 : 0.08;
    final title = widget.postSuccessTitle ?? 'Telefone confirmado!';
    final line = widget.postSuccessStatusLine!.trim();
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
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              line,
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

  Widget _buildCard(ThemeData theme, ColorScheme colorScheme) {
    final shadowA = theme.brightness == Brightness.dark ? 0.35 : 0.08;
    final phoneDisplay =
        PhoneMfaService.e164ToBrazilDisplay(widget.phoneE164);
    final subtitle = widget.intent == PhoneSmsIntent.loginSecondFactor
        ? 'Digite abaixo o código de 6 dígitos para concluir o login.'
        : 'Digite abaixo o código de 6 dígitos para confirmar este número.';

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
              'Verificação por SMS',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            OtpDeliveryBanner(
              channel: OtpDeliveryChannel.sms,
              destinationDetail: phoneDisplay,
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryLabel(theme),
                height: 1.45,
              ),
            ),
            if (_initialSendFailed) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _initialSendFailed = false);
                  _sendInitialSms();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar enviar SMS novamente'),
              ),
            ],
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
                      'Validar código',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                if (_cooldownLeft > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      'Reenviar SMS em ${_cooldownLeft}s',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                      ),
                    ),
                  ),
                Text(
                  'Não recebeu? ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
                GestureDetector(
                  onTap: _svc.canRequestSmsNow ? _onResendTap : null,
                  child: Text(
                    'Enviar novamente',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _svc.canRequestSmsNow
                          ? colorScheme.primary
                          : AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
                        const SizedBox(height: 8),
                        const MesclaAuthHeaderLogo(),
                        const SizedBox(height: 28),
                        _showPostSuccessUi
                            ? _buildPostSuccessCard(theme, colorScheme)
                            : _buildCard(theme, colorScheme),
                        const SizedBox(height: 28),
                        Text(
                          _footerTrust,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.secondaryLabel(
                              theme,
                            ).withValues(alpha: 0.9),
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
