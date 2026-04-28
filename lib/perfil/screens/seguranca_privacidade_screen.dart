// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Segurança: interruptor 2FA (estado local) e recuperação de senha por e-mail.

import 'package:flutter/material.dart';

import '../../auth/screens/recover_password_screen.dart';
import '../../theme/app_colors.dart';
import '../widgets/mescla_subpage_scaffold.dart';

class SegurancaPrivacidadeScreen extends StatefulWidget {
  const SegurancaPrivacidadeScreen({super.key});

  @override
  State<SegurancaPrivacidadeScreen> createState() =>
      _SegurancaPrivacidadeScreenState();
}

class _SegurancaPrivacidadeScreenState extends State<SegurancaPrivacidadeScreen> {
  bool _doisFatoresAtivo = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesclaSubpageScaffold(
      title: 'Segurança e Privacidade',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                _doisFatoresAtivo ? 'Ativado' : 'Desativado',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
              value: _doisFatoresAtivo,
              onChanged: (v) {
                setState(() => _doisFatoresAtivo = v);
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
