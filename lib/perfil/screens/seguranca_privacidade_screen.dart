// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Segurança: interruptor 2FA (Firestore `users/{uid}.twoFactorEnabled`) e recuperação de senha por e-mail.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/recover_password_screen.dart';
import '../../auth/services/user_firestore_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/mescla_subpage_scaffold.dart';

class SegurancaPrivacidadeScreen extends StatefulWidget {
  const SegurancaPrivacidadeScreen({super.key});

  @override
  State<SegurancaPrivacidadeScreen> createState() =>
      _SegurancaPrivacidadeScreenState();
}

class _SegurancaPrivacidadeScreenState extends State<SegurancaPrivacidadeScreen> {
  bool _persisting = false;

  Future<void> _onTwoFactorChanged(bool next) async {
    if (_persisting) return;
    setState(() => _persisting = true);
    try {
      await UserFirestoreService.setTwoFactorLoginEnabled(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'Verificação em duas etapas ativa no próximo login.'
                : 'No próximo login a verificação por e-mail não será pedida.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Não foi possível atualizar a preferência.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao gravar. Verifique a ligação.')),
      );
    } finally {
      if (mounted) {
        setState(() => _persisting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return MesclaSubpageScaffold(
      title: 'Segurança e Privacidade',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (uid == null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'Inicie sessão para ativar ou desativar a verificação em duas etapas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            StreamBuilder<bool>(
              stream: UserFirestoreService.watchTwoFactorLoginEnabled(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Material(
                    color: AppColors.themeCardSurface(theme),
                    borderRadius: BorderRadius.circular(16),
                    child: const SizedBox(
                      height: 88,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final ativo = snapshot.data ?? true;
                return Material(
                  color: AppColors.themeCardSurface(theme),
                  borderRadius: BorderRadius.circular(16),
                  child: SwitchListTile(
                    title: Text(
                      'Verificação em duas etapas (2FA)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      ativo
                          ? 'Ativo: no login enviaremos um código por e-mail.'
                          : 'Inativo: entrada só com e-mail e senha.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                      ),
                    ),
                    value: ativo,
                    onChanged: _persisting ? null : _onTwoFactorChanged,
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          Text(
            'Senha',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(theme),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RecoverPasswordScreen(),
                ),
              );
            },
            icon: const Icon(Icons.lock_reset_outlined),
            label: const Text('Trocar senha por e-mail'),
          ),
        ],
      ),
    );
  }
}
