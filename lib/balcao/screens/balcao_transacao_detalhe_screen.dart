// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Ecrã de **detalhe da transação** após a senha correta no fluxo do Balcão.
// Mostra valores em tokens (pt-BR) + reais e um cartão com data e status.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../theme/app_colors.dart';
import '../balcao_format.dart';
import '../models/balcao_operacao_tipo.dart';
import '../models/balcao_transacao.dart';

/// Apresenta o resumo da operação (compra ou venda).
///
/// O utilizador volta para a mesa do Balcão com o botão da [AppBar] — o
/// [Navigator.pop] remove apenas este ecrã da pilha.
class BalcaoTransacaoDetalheScreen extends StatelessWidget {
  const BalcaoTransacaoDetalheScreen({
    super.key,
    required this.detalhe,
  });

  /// Objeto imutável com todos os campos a mostrar (construído no passo anterior).
  final BalcaoTransacaoDetalhe detalhe;

  static const _padH = 20.0;

  String _dataHoraPtBr(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy às $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final bodyBg = theme.brightness == Brightness.light
        ? AppColors.gradientBottom
        : AppColors.gradientBottomDark;
    final overlay = AppColors.shellOverlayStyle(theme.brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bodyBg,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: onSurface,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: overlay,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Voltar',
          ),
          title: Text(
            'Detalhe da transação',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(_padH, 16, _padH, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                detalhe.operacao == BalcaoOperacaoTipo.compra
                    ? 'Compra concluída'
                    : 'Venda concluída',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Token ${detalhe.nomeToken}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${formatQuantidadeTokensBr(detalhe.quantidadeTokens)} tokens',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatBrl(detalhe.valorReais),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Material(
                color: AppColors.themeCardSurface(theme),
                borderRadius: BorderRadius.circular(20),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Informações',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LinhaDetalhe(
                        rotulo: 'Data e hora',
                        valor: _dataHoraPtBr(detalhe.dataHora),
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _LinhaDetalhe(
                        rotulo: 'Status',
                        valor: detalhe.status,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaDetalhe extends StatelessWidget {
  const _LinhaDetalhe({
    required this.rotulo,
    required this.valor,
    required this.theme,
  });

  final String rotulo;
  final String valor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.secondaryLabel(theme),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
