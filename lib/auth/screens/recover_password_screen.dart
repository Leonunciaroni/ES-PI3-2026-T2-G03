// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';

/// Tela de recuperação de senha com [FirebaseAuth.sendPasswordResetEmail].
///
/// Mensagens de erro passam por [AuthService.messageForPasswordResetError] para
/// alinhar com o resto do app. O texto de sucesso é neutro (enumeração de e-mails).
///
/// [StatefulWidget] para o [TextEditingController] do e-mail e o estado de envio.
class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;

  static const _footerTrust = 'PROJETO INTEGRADOR III - GRUPO 3';

  @override
  void dispose() {
    // Liberta o controller; sem isto o Flutter mantém listeners desnecessários.
    _emailController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Verificação simples só para o protótipo (o servidor validaria de forma completa).
  bool _isEmailPlausible(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  Future<void> _onSendInstructions() async {
    if (_isSending) return;

    final email = _emailController.text;
    if (!_isEmailPlausible(email)) {
      _showSnack('Informe um e-mail válido.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
      _showSnack(
        'Se existir uma conta com este e-mail, receberá instruções em breve.',
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(AuthService.messageForPasswordResetError(e));
    } catch (e) {
      _showSnack(AuthService.messageForPasswordResetError(e));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
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
                // Evita BoxConstraints com altura mínima negativa quando maxHeight ainda é 0.
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
                        // Volta para a tela anterior (normalmente o login).
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
                        const MesclaAuthHeaderLogo(),
                        const SizedBox(height: 24),
                        Text(
                          'Recuperar senha',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enviaremos instruções para o e-mail cadastrado na sua conta.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
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
                                  'Informe seu e-mail',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Use o mesmo endereço que você cadastrou no Mescla Invest.',
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
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _onSendInstructions(),
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
                                    enabledBorder: _stadiumBorder(
                                      fieldStroke,
                                    ),
                                    focusedBorder: _stadiumBorder(
                                      colorScheme.primary,
                                    ),
                                    border: _stadiumBorder(
                                      fieldStroke,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                FilledButton(
                                  onPressed: _isSending
                                      ? null
                                      : _onSendInstructions,
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
                                  child: _isSending
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : const Text(
                                          'Enviar instruções',
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
                                          text: 'Lembrou da senha? ',
                                        ),
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.baseline,
                                          baseline: TextBaseline.alphabetic,
                                          child: GestureDetector(
                                            onTap: () =>
                                                Navigator.of(context).pop(),
                                            child: Text(
                                              'Entrar',
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
