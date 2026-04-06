// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Tela de login apenas visual (sem backend).
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

  /// Quando true, a senha aparece como pontos; o utilizador pode alternar.
  bool _obscurePassword = true;

  static const _footerTrust =
      'PROJETO INTEGRADOR III - GRUPO 3';

  @override
  void dispose() {
    // Libertação de recursos: os controllers mantêm listeners; sem dispose há fugas de memória.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Validação leve só para a demo: evita “Entrar” vazio sem carregar servidor.
  bool _isEmailPlausible(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    // Padrão simples: tem @ e domínio mínimo; o backend real validaria com mais rigor.
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  void _onLogin() {
    final email = _emailController.text;
    final password = _passwordController.text;
    if (!_isEmailPlausible(email)) {
      _showSnack('Informe um e-mail válido.');
      return;
    }
    if (password.isEmpty) {
      _showSnack('Informe a senha.');
      return;
    }
    _showSnack('Protótipo: login aceito (sem API). Próximo passo: backend.');
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
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Barras de estado claras combinam com o fundo em gradiente claro.
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
            // SafeArea evita que o conteúdo fique sob o entalhe ou barra de estado.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // Em ecrãs pequenos o teclado empurra o conteúdo; scroll evita overflow.
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Mescla Invest',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                          color: Colors.white,
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
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    enabledBorder: _stadiumBorder(AppColors.fieldBorder),
                                    focusedBorder: _stadiumBorder(colorScheme.primary),
                                    border: _stadiumBorder(AppColors.fieldBorder),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Text('SENHA', style: labelStyle),
                                    ),
                                    TextButton(
                                      onPressed: () => _showSnack(
                                        'Protótipo: recuperação por e-mail virá com o backend.',
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Esqueci minha senha',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    enabledBorder: _stadiumBorder(AppColors.fieldBorder),
                                    focusedBorder: _stadiumBorder(colorScheme.primary),
                                    border: _stadiumBorder(AppColors.fieldBorder),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                FilledButton(
                                  onPressed: _onLogin,
                                  style: FilledButton.styleFrom(
                                    elevation: 4,
                                    shadowColor: AppColors.primaryShadow(colorScheme),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: const StadiumBorder(),
                                    backgroundColor: colorScheme.primary,
                                  ),
                                  child: const Text(
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
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      children: [
                                        const TextSpan(text: 'Não possui uma conta? '),
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.baseline,
                                          baseline: TextBaseline.alphabetic,
                                          child: GestureDetector(
                                            onTap: () => _showSnack(
                                              'Protótipo: tela de cadastro (nome, CPF, telefone…) será integrada depois.',
                                            ),
                                            child: Text(
                                              'Criar Conta',
                                              style: theme.textTheme.bodyMedium?.copyWith(
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
