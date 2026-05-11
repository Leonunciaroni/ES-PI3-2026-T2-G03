// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Após [UserFirestoreService.createUserWithEmailAndPassword]: envia OTP pela
// callable `twoFactor` (igual ao login), mostra [TwoFactorVerificationScreen],
// depois associa telefone com SMS e abre o dashboard.

import 'package:flutter/material.dart';

import '../../catalog/services/startup_catalog_list_cache.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../theme/app_colors.dart';
import '../services/session_persistence_service.dart';
import '../services/two_factor_service.dart';
import '../services/user_firestore_service.dart';
import 'link_phone_for_mfa_screen.dart';
import 'login_screen.dart';
import 'two_factor_verification_screen.dart';

/// Ecrã agregador: carregamento + envio inicial do código, OTP por e-mail, telefone, dashboard.
class SignupVerificationFlowScreen extends StatefulWidget {
  const SignupVerificationFlowScreen({
    super.key,
    required this.userEmail,
  });

  /// E-mail normalizado (mesmo do cadastro) para exibir no banner da verificação.
  final String userEmail;

  @override
  State<SignupVerificationFlowScreen> createState() =>
      _SignupVerificationFlowScreenState();
}

class _SignupVerificationFlowScreenState
    extends State<SignupVerificationFlowScreen> {
  final TwoFactorService _twoFactor = TwoFactorService();

  bool _sendingInit = true;
  bool _sendFailed = false;
  String? _sendErrorMessage;

  @override
  void initState() {
    super.initState();
    _sendInitialCode();
  }

  Future<void> _sendInitialCode() async {
    setState(() {
      _sendingInit = true;
      _sendFailed = false;
      _sendErrorMessage = null;
    });
    try {
      await _twoFactor.sendCode();
      if (!mounted) {
        return;
      }
      setState(() {
        _sendingInit = false;
        _sendFailed = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sendingInit = false;
        _sendFailed = true;
        _sendErrorMessage = TwoFactorService.messageForError(e);
      });
    }
  }

  Future<void> _exitToLogin() async {
    await UserFirestoreService.signOut();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openPhoneThenDashboard() async {
    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const LinkPhoneForMfaScreen(
          continueToLoginOtp: false,
          showDashboardRedirectAfterSmsVerify: true,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (linked != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Valide o telefone com o código SMS para concluir o cadastro.',
          ),
        ),
      );
      return;
    }

    try {
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
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao concluir: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_sendingInit) {
      final gradientStops = AppColors.shellGradientColors(theme.brightness);
      return Scaffold(
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
          child: const SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Enviando o código de verificação para o seu e-mail…',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_sendFailed) {
      final gradientStops = AppColors.shellGradientColors(theme.brightness);
      return Scaffold(
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Não foi possível enviar o código',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _sendErrorMessage ??
                        'Verifique a ligação e as configurações do projeto.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _sendInitialCode,
                    child: const Text('Tentar enviar código novamente'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _exitToLogin,
                    child: const Text('Sair e voltar ao login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return TwoFactorVerificationScreen(
      replaceStackWithDashboard: false,
      codeDestinationEmail: widget.userEmail,
      twoFactorService: _twoFactor,
      successTitle: 'E-mail confirmado!',
      successStatusMessage:
          'A seguir, confirme o telefone com o código SMS enviado.',
      onVerificationSuccess: _openPhoneThenDashboard,
    );
  }
}
