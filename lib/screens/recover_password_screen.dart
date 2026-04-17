// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Tela de recuperação de senha (protótipo visual).
///
/// No documento do PI, o fluxo real envia instruções por e-mail; aqui só validamos
/// o texto e mostramos [SnackBar], como nas outras telas até existir API no backend.
///
/// Usamos [StatefulWidget] porque o [TextEditingController] do e-mail precisa de
/// [dispose] para não ficar preso na memória após sair da tela.
class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _emailController = TextEditingController();

  /// Caminho registado no [pubspec.yaml] em `flutter: assets:`.
  static const _logoAsset = 'assets/images/mescla_logo.png';

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

  void _onSendInstructions() {
    final email = _emailController.text;
    if (!_isEmailPlausible(email)) {
      _showSnack('Informe um e-mail válido.');
      return;
    }
    _showSnack(
      'Protótipo: instruções seriam enviadas para $email quando o backend estiver pronto.',
    );
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
                        // Logo da marca, centrado no topo conforme identidade visual.
                        Center(
                          child: Image.asset(
                            _logoAsset,
                            height: 88,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.show_chart_rounded,
                                size: 72,
                                color: colorScheme.primary,
                              );
                            },
                          ),
                        ),
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
                          color: Colors.white,
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
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    enabledBorder: _stadiumBorder(
                                      AppColors.fieldBorder,
                                    ),
                                    focusedBorder: _stadiumBorder(
                                      colorScheme.primary,
                                    ),
                                    border: _stadiumBorder(
                                      AppColors.fieldBorder,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                FilledButton(
                                  onPressed: _onSendInstructions,
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
                                  child: const Text(
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
