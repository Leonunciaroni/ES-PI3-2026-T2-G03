// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Passo de **senha ou biometria** no fluxo de saque. Com [debitarSaldoReal] ativo,
// a validação pode ser [EmailAuthProvider] + [reauthenticateWithCredential] ou biometria
// local; depois a Cloud Function [simulateWallet] com `withdraw_pix_simulated`. Modo
// convidado/teste só confirma a UI.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/services/auth_service.dart';
import '../../auth/services/biometric_auth_service.dart';
import '../../auth/services/biometric_shortcut_availability.dart';
import '../../navigation/mescla_material_route.dart';
import '../../theme/app_colors.dart';
import '../format/carteira_brl.dart';
import '../models/pix_chave_ui.dart';
import '../services/simulated_wallet_service.dart';
import 'saque_comprovante_screen.dart';

// --- Ecrã ---------------------------------------------------------------------

/// Confirmação com senha do login; opcionalmente debita saldo via Cloud Function.
class SacarSenhaScreen extends StatefulWidget {
  const SacarSenhaScreen({
    super.key,
    required this.valorReais,
    required this.chavePix,
    this.debitarSaldoReal = true,
  });

  final double valorReais;
  final PixChaveUi chavePix;

  /// Se false (ex.: convidado / testes sem Firebase), não reautentica nem chama a function.
  final bool debitarSaldoReal;

  @override
  State<SacarSenhaScreen> createState() => _SacarSenhaScreenState();
}

class _SacarSenhaScreenState extends State<SacarSenhaScreen> {
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;
  String? _erro;
  bool _enviando = false;

  /// Atalho biométrico (igual ao Balcão), só quando [debitarSaldoReal] é true.
  bool _oferecerBiometria = false;

  bool _disparouPromptBiometriaInicial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _atualizarOfertaBiometria());
  }

  Future<void> _atualizarOfertaBiometria() async {
    if (!widget.debitarSaldoReal) {
      if (mounted) setState(() => _oferecerBiometria = false);
      return;
    }
    final bool ok =
        await BiometricShortcutAvailability.userWantsBiometricShortcut();
    if (!mounted) return;
    setState(() => _oferecerBiometria = ok);
    if (!ok || _disparouPromptBiometriaInicial) return;
    _disparouPromptBiometriaInicial = true;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || !_oferecerBiometria) return;
    await _onConfirmarComBiometria();
  }

  @override
  void dispose() {
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _irParaComprovante() async {
    final agora = DateTime.now();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MesclaMaterialRoute.fadeSlide<void>(
        (context) => SaqueComprovanteScreen(
          valorReais: widget.valorReais,
          chavePix: widget.chavePix,
          dataHora: agora,
        ),
      ),
    );
  }

  Future<void> _onConfirmarComBiometria() async {
    if (_enviando || !widget.debitarSaldoReal) return;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(
        () => _erro = 'Sessão expirada. Entre de novo com seu e-mail e senha.',
      );
      return;
    }

    setState(() {
      _erro = null;
      _enviando = true;
    });

    final BiometricAuthOutcome resultado =
        await BiometricAuthService.instance.authenticate(
      localizedReason: 'Confirme o saque no Mescla Invest.',
      skipPluginAvailabilityPrecheck: true,
    );

    if (resultado != BiometricAuthOutcome.success) {
      if (mounted) {
        setState(() {
          _erro = BiometricAuthService.messageForOutcome(resultado);
          _enviando = false;
        });
      }
      return;
    }

    await _executarSaqueAposIdentidadeVerificada();
  }

  Future<void> _executarSaqueAposIdentidadeVerificada() async {
    try {
      await SimulatedWalletService.withdrawPixSimulated(
        amountBrl: widget.valorReais,
        pixTipoLabel: widget.chavePix.tipoLabel,
        pixDestHint: mascararChavePixComprovante(widget.chavePix.valor),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = SimulatedWalletService.messageForUser(e);
          _enviando = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _enviando = false);
    if (!mounted) return;
    await _irParaComprovante();
  }

  Future<void> _onConfirmar() async {
    if (_enviando) return;

    final password = _senhaController.text;
    if (password.isEmpty) {
      setState(() => _erro = 'Informe sua senha.');
      return;
    }

    if (!widget.debitarSaldoReal) {
      setState(() {
        _enviando = true;
        _erro = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _enviando = false);
      await _irParaComprovante();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(
        () => _erro = 'Sessão expirada. Entre de novo com seu e-mail e senha.',
      );
      return;
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      setState(
        () => _erro =
            'Esta conta não usa senha de e-mail. Não é possível validar aqui.',
      );
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.code == 'invalid-credential' || e.code == 'wrong-password'
              ? 'Senha incorreta. Use a mesma senha do login.'
              : AuthService.messageForError(e);
          _enviando = false;
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = AuthService.messageForError(e);
          _enviando = false;
        });
      }
      return;
    }

    if (!mounted) return;

    await _executarSaqueAposIdentidadeVerificada();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final bodyBg = theme.brightness == Brightness.light
        ? AppColors.gradientBottom
        : AppColors.gradientBottomDark;
    final overlay = AppColors.shellOverlayStyle(theme.brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bodyBg,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: onSurface,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: overlay,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            tooltip: 'Voltar',
          ),
          title: Text(
            'Confirmar saque',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Saque de ${formatBrl(widget.valorReais)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Destino: ${mascararChavePixComprovante(widget.chavePix.valor)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
              const SizedBox(height: 20),
              if (widget.debitarSaldoReal && _oferecerBiometria) ...[
                Material(
                  color: AppColors.themeCardSurface(theme),
                  borderRadius: BorderRadius.circular(16),
                  elevation: 1,
                  shadowColor: Colors.black.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 44,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Primeiro: biometria deste aparelho',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'O sistema pede rosto ou digital como ao abrir o app. '
                          'Se cancelar, use a senha abaixo.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed:
                              _enviando ? null : _onConfirmarComBiometria,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Tentar biometria de novo'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.cardDivider(theme))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ou senha do login',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.cardDivider(theme))),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: _senhaController,
                obscureText: _ocultarSenha,
                enabled: !_enviando,
                keyboardType: TextInputType.visiblePassword,
                onChanged: (_) {
                  if (_erro != null) setState(() => _erro = null);
                },
                decoration: InputDecoration(
                  labelText: 'Senha do login',
                  hintText: 'Sua senha de acesso',
                  filled: true,
                  fillColor: AppColors.searchFieldFillForTheme(theme),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardDivider(theme)),
                  ),
                  suffixIcon: IconButton(
                    onPressed: _enviando
                        ? null
                        : () => setState(() => _ocultarSenha = !_ocultarSenha),
                    icon: Icon(
                      _ocultarSenha
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 10),
                Text(
                  _erro!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _enviando ? null : _onConfirmar,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _enviando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirmar saque'),
              ),
              const SizedBox(height: 16),
              Text(
                widget.debitarSaldoReal
                    ? (_oferecerBiometria
                        ? 'A biometria confirma neste aparelho; a senha revalida a conta no Firebase. O valor será debitado do saldo simulado.'
                        : 'Usamos a mesma senha com que você entra no app. O valor '
                            'será debitado do saldo simulado.')
                    : 'Modo demonstração: o saldo não é alterado.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
