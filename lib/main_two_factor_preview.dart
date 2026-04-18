// Ponto de entrada só para visualizar a verificação 2FA sem alterar main.dart.
// Rode: flutter run -t lib/main_two_factor_preview.dart
//
// Não inicializa Firebase: a tela 2FA não usa Firebase; o app real usa em main.dart.
// Empilha [TwoFactorVerificationScreen] sobre uma rota stub para que, após sucesso,
// [Navigator.pop] volte a esta rota (canPop == true), alinhado ao fluxo com login.
import 'package:flutter/material.dart';

import 'screens/two_factor_verification_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_scroll_behavior.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _TwoFactorPreviewApp());
}

class _TwoFactorPreviewApp extends StatelessWidget {
  const _TwoFactorPreviewApp();

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seedPurple,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.seedPurple,
      onPrimary: const Color(0xFFFFFFFF),
    );

    return MaterialApp(
      title: 'Mescla Invest — 2FA (preview)',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.gradientBottom,
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ),
      home: const _TwoFactorPreviewLauncher(),
    );
  }
}

/// Abre a 2FA com [Navigator.push] para existir rota inferior e o `pop` pós-sucesso funcionar.
class _TwoFactorPreviewLauncher extends StatefulWidget {
  const _TwoFactorPreviewLauncher();

  @override
  State<_TwoFactorPreviewLauncher> createState() =>
      _TwoFactorPreviewLauncherState();
}

class _TwoFactorPreviewLauncherState extends State<_TwoFactorPreviewLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const TwoFactorVerificationScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gradientBottom,
      body: Center(
        child: Text(
          'Preview 2FA — rota stub (após validar 123456, volta aqui)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
