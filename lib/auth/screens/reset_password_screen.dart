// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';

/// Tela para definir nova senha após validar o código de verificação.
///
/// Esta tela é acessada após o usuário validar o código de 6 dígitos
/// na tela de verificação. O código já foi validado pelo Firebase.
///
/// Requisitos da senha (conforme imagem do Figma):
/// - Deve conter 8 caracteres
/// - Pelo menos uma letra maiúscula
/// - Pelo menos um número
/// - Pelo menos um caractere especial
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.oobCode,
  });

  /// Código de confirmação já validado pelo Firebase.
  /// Este código será usado para confirmar a troca de senha.
  final String oobCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// Quando true, a senha aparece como pontos; o utilizador pode alternar.
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  /// Enquanto envia a nova senha ao Firebase, o botão fica desabilitado.
  bool _isSubmitting = false;

  static const _footerTrust = 'PROJETO INTEGRADOR III - GRUPO 3';

  /// Getters para validação em tempo real da senha (igual à tela de criar conta).
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

  @override
  void dispose() {
    // Liberta os controllers; sem isto há fugas de memória.
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Valida se a senha atende a todos os requisitos de segurança.
  /// Retorna uma mensagem de erro ou null se a senha for válida.
  String? _validatePassword(String password) {
    if (!_passwordHasMin8) {
      return 'A senha deve ter pelo menos 8 caracteres.';
    }
    if (!_passwordHasUppercase) {
      return 'A senha deve conter pelo menos uma letra maiúscula.';
    }
    if (!_passwordHasNumber) {
      return 'A senha deve conter pelo menos um número.';
    }
    if (!_passwordHasSpecialChar) {
      return 'A senha deve conter pelo menos um caractere especial.';
    }
    return null;
  }

  /// Envia a nova senha ao Firebase e redireciona para o login em caso de sucesso.
  Future<void> _onConfirmPassword() async {
    if (_isSubmitting) return;

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Valida se os campos estão preenchidos
    if (password.isEmpty || confirmPassword.isEmpty) {
      _showSnack('Preencha ambos os campos de senha.');
      return;
    }

    // Valida se as senhas coincidem
    if (password != confirmPassword) {
      _showSnack('As senhas não coincidem.');
      return;
    }

    // Valida requisitos de segurança
    final validationError = _validatePassword(password);
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Confirma a nova senha com o Firebase usando o código já validado
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: password,
      );

      if (!mounted) return;

      // Mostra mensagem de sucesso
      _showSnack('Senha alterada com sucesso! Faça login com a nova senha.');

      // Volta para a tela de login (remove todas as telas intermediárias)
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      // Trata erros específicos do Firebase
      String errorMessage = 'Não foi possível alterar a senha.';
      switch (e.code) {
        case 'expired-action-code':
          errorMessage = 'O código expirou. Solicite um novo.';
          break;
        case 'invalid-action-code':
          errorMessage = 'O código é inválido. Solicite um novo.';
          break;
        case 'weak-password':
          errorMessage = 'A senha é fraca demais. Tente outra mais forte.';
          break;
        case 'user-disabled':
          errorMessage = 'Esta conta foi desabilitada.';
          break;
        case 'user-not-found':
          errorMessage = 'Usuário não encontrado.';
          break;
        default:
          errorMessage = AuthService.messageForError(e);
      }
      _showSnack(errorMessage);
    } catch (e) {
      _showSnack('Erro inesperado. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Evita BoxConstraints com altura mínima negativa
                final minScrollContentHeight = constraints.maxHeight.isFinite
                    ? (constraints.maxHeight - 24).clamp(0.0, double.infinity)
                    : 0.0;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: minScrollContentHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Volta para a tela anterior
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
                        // Logo Mescla centralizado
                        const MesclaAuthHeaderLogo(),
                        const SizedBox(height: 32),
                        // Card branco com os campos de senha
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
                                // Título
                                Text(
                                  'Nova senha',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Subtítulo
                                Text(
                                  'Digite a nova senha que você quer utilizar para acessar a sua conta',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                // Campo de senha segura
                                Text('SENHA SEGURA *', style: labelStyle),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: AppColors.textSecondary,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppColors.textSecondary,
                                      ),
                                      tooltip: _obscurePassword
                                          ? 'Mostrar senha'
                                          : 'Ocultar senha',
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
                                // Campo de inserir novamente
                                Text('INSERIR NOVAMENTE*', style: labelStyle),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _onConfirmPassword(),
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: AppColors.textSecondary,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppColors.textSecondary,
                                      ),
                                      tooltip: _obscureConfirmPassword
                                          ? 'Mostrar senha'
                                          : 'Ocultar senha',
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
                                const SizedBox(height: 16),
                                // Checklist de validação da senha (igual à tela de criar conta)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _PasswordChecklistRow(
                                        text: 'DEVE CONTER 8 CARACTERES',
                                        satisfied: _passwordHasMin8,
                                        colorScheme: colorScheme,
                                      ),
                                      _PasswordChecklistRow(
                                        text: 'PELO MENOS UMA LETRA MAIÚSCULA',
                                        satisfied: _passwordHasUppercase,
                                        colorScheme: colorScheme,
                                      ),
                                      _PasswordChecklistRow(
                                        text: 'DEVE CONTER NÚMEROS',
                                        satisfied: _passwordHasNumber,
                                        colorScheme: colorScheme,
                                      ),
                                      _PasswordChecklistRow(
                                        text: 'PELO MENOS UM CARACTERE ESPECIAL',
                                        satisfied: _passwordHasSpecialChar,
                                        colorScheme: colorScheme,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),
                                // Botão de confirmar
                                FilledButton(
                                  onPressed:
                                      _isSubmitting ? null : _onConfirmPassword,
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
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : const Text(
                                          'Confirmar',
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
                        // Rodapé
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

/// Widget de checklist para validação de senha (igual ao da tela de criar conta).
///
/// Mostra um ícone de check (✓) quando o requisito está satisfeito,
/// ou um círculo vazio (○) quando ainda não está.
class _PasswordChecklistRow extends StatelessWidget {
  const _PasswordChecklistRow({
    required this.text,
    required this.satisfied,
    required this.colorScheme,
  });

  final String text;
  final bool satisfied;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone de check ou círculo vazio
          Icon(
            satisfied
                ? Icons.check_circle_outline_rounded
                : Icons.circle_outlined,
            size: 16,
            color: satisfied ? colorScheme.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          // Texto do requisito
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
