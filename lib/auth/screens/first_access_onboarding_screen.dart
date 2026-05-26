// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Após o primeiro login de contas com `users/{uid}.firstAccess == true`, obriga à
// verificação do e-mail (Firebase Auth) e à associação do telefone (Phone Auth),
// depois grava `firstAccess: false` e abre o dashboard.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../catalog/services/startup_catalog_list_cache.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../services/phone_mfa_service.dart';
import '../services/session_persistence_service.dart';
import '../services/user_firestore_service.dart';
import 'link_phone_for_mfa_screen.dart';
import 'login_screen.dart';

/// Onboarding único: confirma e-mail e telefone antes do resto do fluxo (2FA, etc.).
class FirstAccessOnboardingScreen extends StatefulWidget {
  const FirstAccessOnboardingScreen({super.key});

  @override
  State<FirstAccessOnboardingScreen> createState() =>
      _FirstAccessOnboardingScreenState();
}

class _FirstAccessOnboardingScreenState extends State<FirstAccessOnboardingScreen> {
  static const _footerTrust = 'PROJETO INTEGRADOR III - GRUPO 3';

  bool _syncingUser = false;
  bool _sendingEmail = false;
  bool _finishing = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _reloadUser();
  }

  Future<void> _reloadUser() async {
    setState(() => _syncingUser = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {
      // Mantém o último estado conhecido.
    } finally {
      if (mounted) {
        setState(() => _syncingUser = false);
      }
    }
  }

  bool get _emailOk => _user?.emailVerified ?? false;

  bool get _phoneOk {
    final pn = _user?.phoneNumber;
    return pn != null && pn.trim().isNotEmpty;
  }

  bool get _canContinue => _emailOk && _phoneOk;

  Future<void> _sendVerificationEmail() async {
    final u = _user;
    if (u == null) {
      return;
    }
    if (_emailOk) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este e-mail já está verificado.')),
        );
      }
      return;
    }
    setState(() => _sendingEmail = true);
    try {
      await u.sendEmailVerification();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'E-mail de verificação enviado. Confira a caixa de entrada e o spam.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      final msg = e.message?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg != null && msg.isNotEmpty
                ? msg
                : 'Não foi possível enviar o e-mail. Tente novamente em instantes.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingEmail = false);
      }
    }
  }

  Future<void> _openLinkPhone() async {
    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const LinkPhoneForMfaScreen(
          continueToLoginOtp: false,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (linked == true) {
      await _reloadUser();
    }
  }

  Future<void> _onContinueToApp() async {
    if (!_canContinue || _finishing) {
      return;
    }
    setState(() => _finishing = true);
    try {
      await _reloadUser();
      if (!_canContinue) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Conclua a verificação do e-mail e do telefone antes de continuar.',
              ),
            ),
          );
        }
        return;
      }
      await UserFirestoreService.markFirstAccessCompleted();
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
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Não foi possível concluir.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _finishing = false);
      }
    }
  }

  Future<void> _signOutAndLeave() async {
    await UserFirestoreService.signOut();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _statusRow({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool done,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: done ? Colors.green : AppColors.textSecondary,
          size: 26,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gradientStops = AppColors.shellGradientColors(theme.brightness);
    final email = _user?.email ?? '';
    final phoneDisplay = _phoneOk
        ? PhoneMfaService.e164ToBrazilDisplay(_user!.phoneNumber!.trim())
        : '';

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
                  Row(
                    children: [
                      TextButton(
                        onPressed: _signOutAndLeave,
                        child: const Text('Sair'),
                      ),
                      const Spacer(),
                      if (_syncingUser)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          onPressed: _reloadUser,
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Atualizar estado',
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const MesclaAuthHeaderLogo(),
                  const SizedBox(height: 24),
                  Text(
                    'Confirme seus dados',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para proteger sua conta, valide o e-mail e confirme o telefone com um código SMS. '
                    'Isto só é pedido uma vez.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Material(
                    elevation: theme.brightness == Brightness.dark ? 8 : 6,
                    shadowColor: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.35 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    color: AppColors.themeCardSurface(theme),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _statusRow(
                            theme: theme,
                            colorScheme: colorScheme,
                            done: _emailOk,
                            title: 'E-mail',
                            subtitle: email.isEmpty
                                ? 'Sem e-mail na sessão.'
                                : email,
                          ),
                          if (!_emailOk) ...[
                            const SizedBox(height: 14),
                            FilledButton.tonal(
                              onPressed: _sendingEmail ? null : _sendVerificationEmail,
                              child: _sendingEmail
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    )
                                  : const Text('Enviar e-mail de verificação'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Depois de abrir o link no e-mail, toque em atualizar '
                              '(ícone acima) ou no botão abaixo.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.secondaryLabel(theme),
                              ),
                            ),
                            TextButton(
                              onPressed: _syncingUser ? null : _reloadUser,
                              child: const Text('Já confirmei — atualizar estado'),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Divider(color: AppColors.cardDivider(theme)),
                          const SizedBox(height: 14),
                          _statusRow(
                            theme: theme,
                            colorScheme: colorScheme,
                            done: _phoneOk,
                            title: 'Telefone (SMS)',
                            subtitle: _phoneOk
                                ? phoneDisplay
                                : 'Associe o mesmo número do cadastro e confirme o código SMS.',
                          ),
                          if (!_phoneOk) ...[
                            const SizedBox(height: 14),
                            FilledButton.tonal(
                              onPressed: _openLinkPhone,
                              child: const Text('Associar e validar telefone'),
                            ),
                          ],
                          const SizedBox(height: 28),
                          FilledButton(
                            onPressed: (_canContinue && !_finishing)
                                ? _onContinueToApp
                                : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: const StadiumBorder(),
                            ),
                            child: _finishing
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    'Continuar para o app',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
