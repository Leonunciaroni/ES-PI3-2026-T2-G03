// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Ecrã mostrado no arranque quando ainda há sessão Firebase válida (24h), a preferência
// de biometria está ligada no Firestore e o aparelho foi inscrito localmente.
// Passo 1: utilizador confirma com Face ID / digital. Passo 2: actualizamos o
// metadado `lastBiometricLoginAt` e abrimos o dashboard.

import 'package:flutter/material.dart';

import '../../dashboard/screens/dashboard_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../services/biometric_auth_service.dart';
import '../services/user_firestore_service.dart';
import 'login_screen.dart';

class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({super.key});

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  bool _pedidoEmCurso = false;
  String? _mensagem;

  @override
  void initState() {
    super.initState();
    // Dispara o diálogo do sistema logo após o primeiro frame (evita build sobre build).
    WidgetsBinding.instance.addPostFrameCallback((_) => _tentarDesbloquear());
  }

  Future<void> _fallbackLoginComSenha() async {
    await UserFirestoreService.signOut();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _tentarDesbloquear() async {
    if (_pedidoEmCurso) return;
    setState(() {
      _pedidoEmCurso = true;
      _mensagem = null;
    });

    final BiometricAuthOutcome outcome =
        await BiometricAuthService.instance.authenticate(
      localizedReason: 'Desbloqueie o Mescla Invest para continuar.',
      skipPluginAvailabilityPrecheck: true,
    );

    if (!mounted) return;

    if (outcome == BiometricAuthOutcome.success) {
      await UserFirestoreService.recordLastBiometricLoginNow();
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
      return;
    }

    setState(() {
      _pedidoEmCurso = false;
      _mensagem = BiometricAuthService.messageForOutcome(outcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const MesclaAuthHeaderLogo(),
              const SizedBox(height: 32),
              Text(
                'Desbloqueio seguro',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use a biometria deste dispositivo para entrar sem escrever a senha de novo. '
                'O MFA continua obrigatório quando a sessão expirar ou após sair da conta.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
              const Spacer(),
              if (_mensagem != null) ...[
                Text(
                  _mensagem!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _pedidoEmCurso ? null : _tentarDesbloquear,
                icon: _pedidoEmCurso
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.fingerprint_rounded),
                label: Text(_pedidoEmCurso ? 'Aguardando…' : 'Tentar de novo'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _pedidoEmCurso ? null : _fallbackLoginComSenha,
                child: const Text('Entrar com e-mail e senha'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
