// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
// Contribuição: Miguel Fernandes Costacurta — RA: 25003110. Integração Firebase Auth e fluxo pós-login.
//
// ┌─────────────────────────────────────────────────────────┐
// │ MIGUEL, O QUE VOCÊ CONTRIBUIU AQUI?                     │
// │                                                         │
// │ Você integrou o Firebase Auth no fluxo de login e       │
// │ implementou a lógica pós-login: verificar primeiro       │
// │ acesso, checar se o 2FA está ativo no Firestore e       │
// │ redirecionar para a tela correta.                       │
// │                                                         │
// │ PARA ESTUDAR (foque no método _onLogin):                │
// │   1. Firebase Auth: signInWithEmailAndPassword          │
// │      → O que retorna? O que acontece se a senha errar?  │
// │   2. Firestore: leitura de um campo (isTwoFactorEnabled)│
// │   3. Flutter: navegação com pushAndRemoveUntil          │
// │   4. Dart: try/catch para erros do Firebase             │
// │   5. Flutter: mounted — checagem obrigatória após await │
// └─────────────────────────────────────────────────────────┘

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/session_persistence_service.dart';
import '../services/user_firestore_service.dart';
import '../services/two_factor_service.dart';
import '../../catalog/services/startup_catalog_list_cache.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../services/auth_service.dart';
import '../services/phone_mfa_service.dart';
import 'create_account_screen.dart';
import 'first_access_onboarding_screen.dart';
import 'link_phone_for_mfa_screen.dart';
import 'phone_sms_verification_screen.dart';
import 'recover_password_screen.dart';
import 'two_factor_verification_screen.dart';

/// Tela de login integrada ao Firebase Auth.
///
/// Usamos [StatefulWidget] porque a visibilidade da senha muda ao tocar no ícone
/// do olho — isso exige [setState] para reconstruir o [TextField] com
/// [obscureText] diferente.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Quando true, a senha aparece como pontos; o usuário pode alternar.
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  final _twoFactorService = TwoFactorService();

  static const _footerTrust = 'PROJETO INTEGRADOR III - GRUPO 3';

  @override
  void dispose() {
    // Liberação de recursos: os controllers mantêm listeners; sem dispose há vazamentos de memória.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Validação leve só para a demo: evita “Entrar” vazio sem carregar servidor.
  bool _isEmailPlausible(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    // Padrão simples: tem @ e domínio mínimo; o backend real validaria com mais rigor.
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  Future<void> _onLogin() async {
    if (_isSubmitting) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_isEmailPlausible(email)) {
      _showSnack('Informe um e-mail válido.');
      return;
    }
    if (password.isEmpty) {
      _showSnack('Informe a senha.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      // [MIGUEL - ESTUDE] PASSO 1: Autentica com Firebase Auth.
      // signInWithEmailAndPassword verifica a senha no servidor do Firebase.
      // Se a senha estiver errada → lança FirebaseAuthException (vai pro catch).
      // Se estiver certa → o Firebase cria uma sessão e FirebaseAuth.currentUser
      // passa a ter o usuário logado.
      // → ESTUDE: o que é uma "sessão" no Firebase? Quanto tempo ela dura?
      await UserFirestoreService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // [MIGUEL - ESTUDE] mounted é um bool do State do Flutter.
      // Depois de qualquer await, a tela pode ter sido fechada pelo usuário.
      // Se !mounted, não podemos mais chamar setState ou Navigator.
      if (!mounted) return;

      // [MIGUEL - ESTUDE] PASSO 2: Verifica se é primeiro acesso.
      // Lê o campo firstAccess do Firestore (users/{uid}.firstAccess).
      // Se true → usuário nunca completou a verificação de e-mail/telefone.
      // → ESTUDE: por que essa verificação fica no Firestore e não no Firebase Auth?
      //   R: o Firebase Auth só sabe de autenticação. Dados extras ficam no Firestore.
      final firstAccessPending =
          await UserFirestoreService.isFirstAccessPending();
      if (!mounted) return;
      if (firstAccessPending) {
        await Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            builder: (_) => const FirstAccessOnboardingScreen(),
          ),
          (route) => false,
        );
        return;
      }

      // [MIGUEL - ESTUDE] PASSO 3: Verifica se o 2FA está ativo.
      // Lê users/{uid}.twoFactorEnabled no Firestore.
      // Se false → vai direto pro Dashboard (sem pedir código OTP).
      // Se true → continua e envia o código OTP.
      // 2. Conforme preferência em `users/{uid}.twoFactorEnabled`, envia OTP ou entra direto.
      final twoFaOn = await UserFirestoreService.isTwoFactorLoginEnabled();
      if (!mounted) return;

      if (!twoFaOn) {
        StartupCatalogListCache.instance.clear();
        // [MIGUEL - ESTUDE] recordSessionAfterLogin() salva no SharedPreferences
        // a hora atual + 24h como prazo de validade da sessão.
        // Isso é lido pelo AuthGateScreen (que você fez) para decidir
        // se pode pular pro desbloqueio biométrico sem login.
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

      // [MIGUEL - ESTUDE] PASSO 4: Lê o método de entrega do código.
      // mfaDeliveryMethod pode ser "email" ou "sms".
      // Se "sms" → envia código por SMS (Firebase Phone Auth)
      // Se "email" → envia código por e-mail (via Cloud Function "twoFactor")
      // → ESTUDE: o que é Firebase Phone Auth?
      // → ESTUDE: o que é uma Cloud Function callable? Como o Flutter chama?
      // 3. Canal MFA: SMS (Firebase Phone) ou e-mail (Cloud Function).
      final mfaMethod = await UserFirestoreService.fetchMfaDeliveryMethod();
      if (!mounted) {
        return;
      }

      if (mfaMethod == UserFirestoreService.mfaDeliverySms) {
        final authUser = FirebaseAuth.instance.currentUser;
        final phoneAuth = authUser?.phoneNumber;

        if (phoneAuth == null || phoneAuth.isEmpty) {
          final goLink = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('Associar telefone'),
                content: const Text(
                  'Para MFA por SMS é preciso associar um número ao Firebase Auth. '
                  'Deseja continuar para enviar o código de verificação?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Continuar'),
                  ),
                ],
              );
            },
          );
          if (!mounted) {
            return;
          }
          if (goLink != true) {
            await UserFirestoreService.signOut();
            _showSnack(
              'Login cancelado. Para MFA por SMS associe o telefone em Segurança.',
            );
            return;
          }

          final linkedOk = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => const LinkPhoneForMfaScreen(
                continueToLoginOtp: true,
              ),
            ),
          );
          if (!mounted) {
            return;
          }
          if (linkedOk != true) {
            await UserFirestoreService.signOut();
            _showSnack(
              'É necessário associar o telefone para concluir o login com SMS.',
            );
            return;
          }
          return;
        }

        final phoneSvc = PhoneMfaService();
        try {
          await phoneSvc.requestSmsCode(
            phoneE164: phoneAuth,
            intent: PhoneSmsIntent.loginSecondFactor,
          );
        } catch (sendError) {
          if (!mounted) {
            return;
          }
          await UserFirestoreService.signOut();
          _showSnack(PhoneMfaService.messageForError(sendError));
          return;
        }

        if (!mounted) {
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => PhoneSmsVerificationScreen(
              phoneMfaService: phoneSvc,
              phoneE164: phoneAuth,
              intent: PhoneSmsIntent.loginSecondFactor,
              smsAlreadyRequested: true,
              replaceStackWithDashboard: true,
            ),
          ),
        );
        return;
      }

      try {
        await _twoFactorService.sendCode();
      } catch (sendError) {
        if (!mounted) return;
        _showSnack(TwoFactorService.messageForError(sendError));
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TwoFactorVerificationScreen(
            replaceStackWithDashboard: true,
            twoFactorService: _twoFactorService,
            codeDestinationEmail: email,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(AuthService.messageForError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  OutlineInputBorder _stadiumBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Bordas de campo: Figma claro; no escuro usamos o contorno do [ColorScheme].
    final fieldStroke = theme.brightness == Brightness.light
        ? AppColors.fieldBorder
        : colorScheme.outline;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    );
    final gradientStops = AppColors.shellGradientColors(theme.brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Ícones da status bar: escuros em fundo claro, claros em fundo escuro.
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
            // SafeArea evita que o conteúdo fique sob o entalhe ou barra de estado.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // Em telas pequenas o teclado empurra o conteúdo; scroll evita overflow.
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
                        const SizedBox(height: 24),
                        Text(
                          'Invista nas melhores startups da PUC-Campinas.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Material(
                          elevation: 6,
                          shadowColor: Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(30),
                          color: colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Bem-vindo de volta',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Acesse sua conta para gerenciar seus investimentos.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Text('E-MAIL', style: labelStyle),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    hintText: 'exemplo@email.com',
                                    prefixIcon: Icon(
                                      Icons.mail_outline,
                                      color: AppColors.textSecondary,
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    enabledBorder: _stadiumBorder(fieldStroke),
                                    focusedBorder: _stadiumBorder(
                                      colorScheme.primary,
                                    ),
                                    border: _stadiumBorder(fieldStroke),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text('SENHA', style: labelStyle),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _onLogin(),
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: AppColors.textSecondary,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Mostrar senha'
                                          : 'Ocultar senha',
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    enabledBorder: _stadiumBorder(fieldStroke),
                                    focusedBorder: _stadiumBorder(
                                      colorScheme.primary,
                                    ),
                                    border: _stadiumBorder(fieldStroke),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () {
                                            Navigator.push<void>(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (context) =>
                                                    const RecoverPasswordScreen(),
                                              ),
                                            );
                                          },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Esqueci minha senha',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                FilledButton(
                                  onPressed: _isSubmitting ? null : _onLogin,
                                  style: FilledButton.styleFrom(
                                    elevation: 4,
                                    shadowColor: AppColors.primaryShadow(
                                      colorScheme,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: const StadiumBorder(),
                                    backgroundColor: colorScheme.primary,
                                  ),
                                  child: _isSubmitting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : const Text(
                                          'Entrar',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: Text.rich(
                                    TextSpan(
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                      children: [
                                        const TextSpan(
                                          text: 'Não possui uma conta? ',
                                        ),
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.baseline,
                                          baseline: TextBaseline.alphabetic,
                                          child: GestureDetector(
                                            onTap: _isSubmitting
                                                ? null
                                                : () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            const CreateAccountScreen(),
                                                      ),
                                                    );
                                                  },
                                            child: Text(
                                              'Criar Conta',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
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
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.85,
                            ),
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
