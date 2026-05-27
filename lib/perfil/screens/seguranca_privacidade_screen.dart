// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Segurança: 2FA (`users/{uid}.twoFactorEnabled`), canal MFA (`mfaDeliveryMethod`),
// escolha explícita de biometria (não usar / usar), recuperação de senha por e-mail.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/link_phone_for_mfa_screen.dart';
import '../../auth/screens/recover_password_screen.dart';
import '../../auth/services/biometric_auth_service.dart';
import '../../auth/services/biometric_enrollment_storage.dart';
import '../../auth/services/user_firestore_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/mescla_subpage_scaffold.dart';
import 'termos_uso_privacidade_screen.dart';

/// Dados lidos uma vez para o texto do tipo de leitor (digital, Face ID, …).
class _BioUiInfo {
  const _BioUiInfo({required this.podeUsar, required this.descricaoHardware});

  final bool podeUsar;
  final String descricaoHardware;
}

class SegurancaPrivacidadeScreen extends StatefulWidget {
  const SegurancaPrivacidadeScreen({super.key});

  @override
  State<SegurancaPrivacidadeScreen> createState() =>
      _SegurancaPrivacidadeScreenState();
}

class _SegurancaPrivacidadeScreenState
    extends State<SegurancaPrivacidadeScreen> {
  bool _persisting = false;

  /// Carrega capacidades do aparelho (biometria disponível + texto para o subtítulo).
  late final Future<_BioUiInfo> _futureBioUiInfo = _carregarBioUiInfo();

  static bool _plataformaComBiometriaNativa() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<_BioUiInfo> _carregarBioUiInfo() async {
    if (!_plataformaComBiometriaNativa()) {
      return const _BioUiInfo(podeUsar: false, descricaoHardware: '');
    }
    final svc = BiometricAuthService.instance;
    final pode = await svc.deviceCanUseBiometrics();
    final texto = pode ? await svc.describeHardwareForUi() : '';
    return _BioUiInfo(podeUsar: pode, descricaoHardware: texto);
  }

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

    // Se a biometria está ativa neste aparelho, exigimos o mesmo desafio antes de mudar 2FA.
    final String? uid = _currentUidOrNull();
    if (uid != null) {
      final bool prefBio = await UserFirestoreService.fetchBiometricEnabled();
      final bool inscrito = await BiometricEnrollmentStorage.isEnrolledForUser(
        uid,
      );
      if (prefBio && inscrito) {
        final BiometricAuthOutcome
        prova = await BiometricAuthService.instance.authenticate(
          localizedReason:
              'Confirme com a biometria para alterar a verificação em duas etapas.',
          skipPluginAvailabilityPrecheck: true,
        );
        if (prova != BiometricAuthOutcome.success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(BiometricAuthService.messageForOutcome(prova)),
            ),
          );
          return;
        }
      }
    }

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
        const SnackBar(content: Text('Erro ao gravar. Verifique a conexão.')),
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

    final String? uidMfa = _currentUidOrNull();
    if (uidMfa != null) {
      final bool prefBio = await UserFirestoreService.fetchBiometricEnabled();
      final bool inscrito = await BiometricEnrollmentStorage.isEnrolledForUser(
        uidMfa,
      );
      if (prefBio && inscrito) {
        final BiometricAuthOutcome
        prova = await BiometricAuthService.instance.authenticate(
          localizedReason:
              'Confirme com a biometria para alterar o canal do código MFA.',
          skipPluginAvailabilityPrecheck: true,
        );
        if (prova != BiometricAuthOutcome.success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(BiometricAuthService.messageForOutcome(prova)),
            ),
          );
          return;
        }
      }
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

  /// Utilizador escolhe explicitamente **não usar** ou **usar** biometria (rádio na UI).
  Future<void> _onBiometricUserChoice({
    required bool querAtivar,
    required bool valorFirestoreActual,
  }) async {
    if (_persisting) return;
    if (querAtivar == valorFirestoreActual) return;

    final String? uid = _currentUidOrNull();
    if (uid == null) return;

    // Desligar: não precisamos de biometria; só sincronizamos Firestore + apagamos marca local.
    if (!querAtivar) {
      setState(() => _persisting = true);
      try {
        await UserFirestoreService.setBiometricEnabled(false);
        await BiometricEnrollmentStorage.clearEnrollment();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometria desativada. Da próxima vez use e-mail e senha ao abrir o app.',
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
          const SnackBar(content: Text('Erro ao gravar. Verifique a conexão.')),
        );
      } finally {
        if (mounted) setState(() => _persisting = false);
      }
      return;
    }

    // Ligar: primeiro o sistema confirma que quem mexe no celular é o dono da biometria.
    if (!_plataformaComBiometriaNativa()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometria só está disponível nas apps Android e iOS.'),
        ),
      );
      return;
    }

    final info = await _futureBioUiInfo;
    if (!info.podeUsar) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            BiometricAuthService.messageForOutcome(
              BiometricAuthOutcome.notAvailable,
            ),
          ),
        ),
      );
      return;
    }

    final BiometricAuthOutcome prova = await BiometricAuthService.instance
        .authenticate(
          localizedReason: 'Ativar biometria no Mescla Invest.',
          skipPluginAvailabilityPrecheck: true,
        );
    if (prova != BiometricAuthOutcome.success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BiometricAuthService.messageForOutcome(prova))),
      );
      return;
    }

    setState(() => _persisting = true);
    try {
      await UserFirestoreService.setBiometricEnabled(true);
      await BiometricEnrollmentStorage.setEnrolledForUser(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometria ativada: pode desbloquear o app com Face ID ou digital quando a sessão ainda for válida.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Não foi possível gravar no servidor.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao gravar. Verifique a conexão.')),
      );
    } finally {
      if (mounted) setState(() => _persisting = false);
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
                'Faça login para gerenciar duas etapas, biometria e outros controles de segurança.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<bool>(
                  stream: UserFirestoreService.watchTwoFactorLoginEnabled(),
                  builder: (context, snapshot2fa) {
                    if (snapshot2fa.connectionState ==
                            ConnectionState.waiting &&
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
                            stream:
                                UserFirestoreService.watchMfaDeliveryMethod(),
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
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                      ),
                                    ),
                                    RadioListTile<String>(
                                      title: const Text('E-mail'),
                                      value:
                                          UserFirestoreService.mfaDeliveryEmail,
                                      groupValue: method,
                                      onChanged: _persisting
                                          ? null
                                          : (v) {
                                              if (v != null) {
                                                _onMfaDeliveryChanged(v);
                                              }
                                            },
                                    ),
                                    RadioListTile<String>(
                                      title: const Text('SMS'),
                                      value:
                                          UserFirestoreService.mfaDeliverySms,
                                      groupValue: method,
                                      onChanged: _persisting
                                          ? null
                                          : (v) {
                                              if (v != null) {
                                                _onMfaDeliveryChanged(v);
                                              }
                                            },
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
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppColors.secondaryLabel(
                                                theme,
                                              ),
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
                  'Biometria no dispositivo',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<_BioUiInfo>(
                  future: _futureBioUiInfo,
                  builder: (context, snapHw) {
                    if (snapHw.connectionState == ConnectionState.waiting &&
                        !snapHw.hasData) {
                      return Material(
                        color: AppColors.themeCardSurface(theme),
                        borderRadius: BorderRadius.circular(16),
                        child: const SizedBox(
                          height: 72,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    final hw =
                        snapHw.data ??
                        const _BioUiInfo(
                          podeUsar: false,
                          descricaoHardware: '',
                        );
                    if (!_plataformaComBiometriaNativa()) {
                      return Text(
                        'A biometria nativa (Face ID / digital) só está disponível nas versões Android e iOS do app.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                          height: 1.35,
                        ),
                      );
                    }
                    return StreamBuilder<bool>(
                      stream: UserFirestoreService.watchBiometricEnabled(),
                      builder: (context, snapBio) {
                        if (snapBio.connectionState ==
                                ConnectionState.waiting &&
                            !snapBio.hasData) {
                          return const SizedBox.shrink();
                        }
                        final bool bioActiva = snapBio.data ?? false;
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
                                  'Escolha se quer usar biometria neste aparelho',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  0,
                                ),
                                child: Text(
                                  'Isto não substitui a senha na primeira entrada nem o MFA quando a sessão expira.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.secondaryLabel(theme),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              RadioListTile<bool>(
                                title: const Text('Não usar biometria'),
                                subtitle: const Text(
                                  'Login e confirmações sensíveis continuam com senha (e MFA, se estiver ligado).',
                                ),
                                value: false,
                                groupValue: bioActiva,
                                onChanged: _persisting
                                    ? null
                                    : (_) => _onBiometricUserChoice(
                                        querAtivar: false,
                                        valorFirestoreActual: bioActiva,
                                      ),
                              ),
                              RadioListTile<bool>(
                                title: const Text('Usar biometria'),
                                subtitle: Text(
                                  hw.podeUsar
                                      ? 'Desbloqueio com: ${hw.descricaoHardware}'
                                      : 'Neste aparelho não há leitor biométrico configurado. Use as configurações do sistema.',
                                ),
                                value: true,
                                groupValue: bioActiva,
                                onChanged: _persisting || !hw.podeUsar
                                    ? null
                                    : (_) => _onBiometricUserChoice(
                                        querAtivar: true,
                                        valorFirestoreActual: bioActiva,
                                      ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 24),
          Text(
            'Documentos',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(theme),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.themeCardSurface(theme),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Termos de Uso'),
              subtitle: const Text('Política de Privacidade'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const TermosUsoPrivacidadeScreen(),
                  ),
                );
              },
            ),
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
