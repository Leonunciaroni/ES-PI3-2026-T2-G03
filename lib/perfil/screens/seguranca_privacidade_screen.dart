// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Segurança: interruptor 2FA (`users/{uid}.twoFactorEnabled`), canal MFA (`mfaDeliveryMethod`)
// e recuperação de senha por e-mail.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/link_phone_for_mfa_screen.dart';
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

class _SegurancaPrivacidadeScreenState
    extends State<SegurancaPrivacidadeScreen> {
  bool _persisting = false;

  /// Sem [Firebase.initializeApp] (ex.: alguns `flutter test`), evita lançar ao ler a sessão.
  String? _currentUidOrNull() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

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
                : 'No próximo login só será pedido e-mail e senha (sem segundo fator).',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Não foi possível atualizar a preferência.',
          ),
        ),
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

  /// Diálogo simples para confirmar a senha ao mudar de SMS para e-mail (recuperação sem SMS).
  Future<String?> _promptLoginPassword() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirmar senha'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Senha da conta',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => Navigator.of(ctx).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    final text = controller.text.trim();
    controller.dispose();
    if (ok != true) {
      return null;
    }
    return text.isEmpty ? null : text;
  }

  /// Altera o canal MFA no Firestore; SMS pode exigir associar telefone ou senha ao voltar para e-mail.
  Future<void> _onMfaDeliveryChanged(String nextMethod) async {
    if (_persisting) {
      return;
    }

    final current = await UserFirestoreService.fetchMfaDeliveryMethod();
    if (!mounted || nextMethod == current) {
      return;
    }

    if (nextMethod == UserFirestoreService.mfaDeliverySms) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final hasPhone =
            user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty;

        if (!hasPhone) {
          final linked = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) =>
                  const LinkPhoneForMfaScreen(continueToLoginOtp: false),
            ),
          );
          if (!mounted || linked != true) {
            return;
          }
        }

        setState(() => _persisting = true);
        await UserFirestoreService.setMfaDeliveryMethod(
          UserFirestoreService.mfaDeliverySms,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Próximo login: código MFA por SMS.')),
        );
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) {
          setState(() => _persisting = false);
        }
      }
      return;
    }

    // Mudança para e-mail.
    if (current == UserFirestoreService.mfaDeliverySms) {
      final pw = await _promptLoginPassword();
      if (pw == null || !mounted) {
        return;
      }
      setState(() => _persisting = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        final email = user?.email;
        if (user == null || email == null) {
          throw FirebaseAuthException(
            code: 'invalid-user',
            message: 'Conta sem e-mail.',
          );
        }
        final cred = EmailAuthProvider.credential(email: email, password: pw);
        await user.reauthenticateWithCredential(cred);
        await UserFirestoreService.setMfaDeliveryMethod(
          UserFirestoreService.mfaDeliveryEmail,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Próximo login: código MFA por e-mail. '
              'Se perder acesso ao telefone, pode voltar aqui com a senha.',
            ),
          ),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Senha incorreta.')),
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar o canal MFA.'),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _persisting = false);
        }
      }
      return;
    }

    setState(() => _persisting = true);
    try {
      await UserFirestoreService.setMfaDeliveryMethod(
        UserFirestoreService.mfaDeliveryEmail,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Próximo login: código MFA por e-mail.')),
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
    final uid = _currentUidOrNull();

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
              builder: (context, snapshot2fa) {
                if (snapshot2fa.connectionState == ConnectionState.waiting &&
                    !snapshot2fa.hasData) {
                  return Material(
                    color: AppColors.themeCardSurface(theme),
                    borderRadius: BorderRadius.circular(16),
                    child: const SizedBox(
                      height: 88,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final ativo = snapshot2fa.data ?? true;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
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
                              ? 'Ativo: no login será pedido um segundo fator.'
                              : 'Inativo: entrada só com e-mail e senha.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                          ),
                        ),
                        value: ativo,
                        onChanged: _persisting ? null : _onTwoFactorChanged,
                      ),
                    ),
                    if (ativo) ...[
                      const SizedBox(height: 12),
                      StreamBuilder<String>(
                        stream: UserFirestoreService.watchMfaDeliveryMethod(),
                        builder: (context, snapMfa) {
                          if (snapMfa.connectionState ==
                                  ConnectionState.waiting &&
                              !snapMfa.hasData) {
                            return const SizedBox.shrink();
                          }
                          final method =
                              snapMfa.data ??
                              UserFirestoreService.mfaDeliveryEmail;
                          return Material(
                            color: AppColors.themeCardSurface(theme),
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    0,
                                  ),
                                  child: Text(
                                    'Canal do código MFA',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                RadioGroup<String>(
                                  groupValue: method,
                                  onChanged: (value) {
                                    if (!_persisting && value != null) {
                                      _onMfaDeliveryChanged(value);
                                    }
                                  },
                                  child: Column(
                                    children: [
                                      RadioListTile<String>(
                                        enabled: !_persisting,
                                        title: const Text('E-mail'),
                                        value: UserFirestoreService
                                            .mfaDeliveryEmail,
                                      ),
                                      RadioListTile<String>(
                                        enabled: !_persisting,
                                        title: const Text('SMS'),
                                        value:
                                            UserFirestoreService.mfaDeliverySms,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Text(
                                    'Se perder o telefone, escolha e-mail e confirme com a senha.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.secondaryLabel(theme),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
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
