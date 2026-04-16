//Miguel Fernandes Costacurta - 25003110
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_screen.dart';
import '../theme/app_colors.dart';

/// Tela de cadastro apenas visual, desenhada com componentes do Material 3.
///
/// Esta tela não chama API nem salva dados: o foco aqui e no layout para o PI.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  bool get _passwordHasMin8 {
    final value = _passwordController.text;
    return value.length >= 8;
  }

  bool get _passwordHasUppercase {
    final value = _passwordController.text;
    return RegExp(r'[A-Z]').hasMatch(value);
  }

  bool get _passwordHasNumber {
    final value = _passwordController.text;
    return RegExp(r'[0-9]').hasMatch(value);
  }

  bool get _passwordHasSpecialChar {
    final value = _passwordController.text;
    return RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  bool get _passwordMatchesConfirmation {
    return _passwordController.text == _confirmPasswordController.text;
  }

  @override
  void dispose() {
    // Boas praticas: libera listeners internos dos controllers.
    _nameController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  OutlineInputBorder _stadiumBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: color),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: _stadiumBorder(AppColors.fieldBorder),
      focusedBorder: _stadiumBorder(colorScheme.primary),
      border: _stadiumBorder(AppColors.fieldBorder),
    );
  }

  void _showFeatureMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onCreateAccount() {
    if (!_acceptedTerms) {
      _showFeatureMessage(
        'Aceite os Termos de Uso e a Política de Privacidade para continuar.',
      );
      return;
    }

    if (!_passwordMatchesConfirmation) {
      _showFeatureMessage(
        'As senhas não conferem. Verifique o campo de confirmação.',
      );
      return;
    }

    final hasAllRules =
        _passwordHasMin8 &&
        _passwordHasUppercase &&
        _passwordHasNumber &&
        _passwordHasSpecialChar;

    if (!hasAllRules) {
      _showFeatureMessage(
        'Sua senha não atende a todos os critérios de senha segura.',
      );
      return;
    }

    _showFeatureMessage('Protótipo visual: conta criada (sem backend).');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final criteriaTextStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary.withValues(alpha: 0.85),
      letterSpacing: 0.5,
      height: 1.35,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
              colors: [AppColors.gradientTop, AppColors.gradientBottom],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              // Scroll evita overflow quando teclado abre em ecras menores.
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Voltar para a tela anterior (geralmente login).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.textSecondary,
                      tooltip: 'Voltar',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Image.asset(
                      'assets/images/mescla_logo.png',
                      width: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Criar Conta',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inicie sua jornada no mercado de venture capital em poucos minutos.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildLabel(context, 'NOME COMPLETO *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      context: context,
                      hintText: 'Como deseja ser chamado?',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildLabel(context, 'E-MAIL PESSOAL *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      context: context,
                      hintText: 'seu@email.com.br',
                      icon: Icons.mail_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildLabel(context, 'CPF *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      context: context,
                      hintText: '000.000.000-00',
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildLabel(context, 'SENHA SEGURA *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      context: context,
                      hintText: '********',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildLabel(context, 'INSERIR NOVAMENTE *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      context: context,
                      hintText: '********',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmPassword
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PasswordChecklistRow(
                          text: 'DEVE CONTER 8 CARACTERE',
                          satisfied: _passwordHasMin8,
                          colorScheme: colorScheme,
                          baseStyle: criteriaTextStyle,
                        ),
                        _PasswordChecklistRow(
                          text: 'PELO MENOS UMA LETRA MAIÚSCULA',
                          satisfied: _passwordHasUppercase,
                          colorScheme: colorScheme,
                          baseStyle: criteriaTextStyle,
                        ),
                        _PasswordChecklistRow(
                          text: 'DEVE CONTER NÚMEROS',
                          satisfied: _passwordHasNumber,
                          colorScheme: colorScheme,
                          baseStyle: criteriaTextStyle,
                        ),
                        _PasswordChecklistRow(
                          text: 'PELO MENOS UM CARACTERE ESPECIAL',
                          satisfied: _passwordHasSpecialChar,
                          colorScheme: colorScheme,
                          baseStyle: criteriaTextStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        onChanged: (value) {
                          setState(() => _acceptedTerms = value ?? false);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 11),
                          child: Text.rich(
                            TextSpan(
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                              children: [
                                const TextSpan(text: 'Li e aceito os '),
                                TextSpan(
                                  text: 'Termos de Uso',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: ' e a '),
                                TextSpan(
                                  text: 'Politica de Privacidade',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _onCreateAccount,
                    style: FilledButton.styleFrom(
                      elevation: 3,
                      shadowColor: AppColors.primaryShadow(colorScheme),
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: const StadiumBorder(),
                      backgroundColor: colorScheme.primary,
                    ),
                    child: const Text(
                      'Criar Conta →',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          const TextSpan(text: 'Já possui uma conta? '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Fazer Login',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordChecklistRow extends StatelessWidget {
  const _PasswordChecklistRow({
    required this.text,
    required this.satisfied,
    required this.colorScheme,
    required this.baseStyle,
  });

  final String text;
  final bool satisfied;
  final ColorScheme colorScheme;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            satisfied
                ? Icons.check_circle_outline_rounded
                : Icons.circle_outlined,
            size: 16,
            color: satisfied ? colorScheme.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: (baseStyle ?? const TextStyle()).copyWith(
                color: satisfied ? colorScheme.primary : baseStyle?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
