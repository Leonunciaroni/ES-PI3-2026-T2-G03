// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Perguntas frequentes e contacto (conteúdo de exemplo para o app).

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../widgets/mescla_subpage_scaffold.dart';

class AjudaSuporteScreen extends StatelessWidget {
  const AjudaSuporteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesclaSubpageScaffold(
      title: 'Ajuda e Suporte',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Dúvidas frequentes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _ajudaItem(
            theme,
            'Como adiciono saldo à minha carteira?',
            'Na tela de Carteira, use o botão de adicionar saldo e siga o '
            'passo a passo com o valor pretendido. O crédito é simulado na app.',
          ),
          const SizedBox(height: 16),
          _ajudaItem(
            theme,
            'Onde compro ou vendo tokens?',
            'No Balcão encontra as ofertas de startups. Pode ir direto a uma startup no '
            'catálogo ou negociar na área de balcão, conforme a sua estratégia.',
          ),
          const SizedBox(height: 16),
          _ajudaItem(
            theme,
            'Quanto tempo demora um saque simulado?',
            'Neste ambiente, as movimentações são processadas de imediato. Pode '
            'acompanhar o histórico em Carteira, na secção de movimentações.',
          ),
          const SizedBox(height: 16),
          _ajudaItem(
            theme,
            'Como ativo a verificação em duas etapas?',
            'Abra Perfil, Segurança e Privacidade, e ative o botão de 2FA. '
            'Pode ajustar quando quiser sem sair da tela.',
          ),
          const SizedBox(height: 24),
          Text(
            'Fale connosco',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Suporte: suporte_exemplo@mesclainvest.app\n'
            'Segunda a sexta, 09h–18h (resposta em até 1 dia útil).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _ajudaItem(ThemeData theme, String pergunta, String resposta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pergunta,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          resposta,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
