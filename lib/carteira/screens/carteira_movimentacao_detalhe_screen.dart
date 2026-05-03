// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// **Comprovante** de uma movimentação da Carteira (“Ver detalhes”), no mesmo
// padrão visual de [SaqueComprovanteScreen]: AppBar “Comprovante”, estado,
// subtítulo, valor em roxo, linha opcional, cartão Informações e botão roxo
// “Voltar à carteira”.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../models/carteira_movimentacao_detalhe.dart';

/// Comprovante para uma linha de “Minhas Movimentações”.
class CarteiraMovimentacaoDetalheScreen extends StatelessWidget {
  const CarteiraMovimentacaoDetalheScreen({
    super.key,
    required this.detalhe,
  });

  final CarteiraMovimentacaoDetalhe detalhe;

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
    final rodape = detalhe.linhaRodapeOpcional;

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
            'Comprovante',
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
                detalhe.tituloConclusao,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detalhe.subtitulo,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                detalhe.valorReaisExibicao,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              if (rodape != null && rodape.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  rodape,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
              ],
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
                      _LinhaInfoComprovante(
                        rotulo: 'Data e hora',
                        valor: _dataHoraPtBr(detalhe.dataHora),
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _LinhaInfoComprovante(
                        rotulo: 'Status',
                        valor: detalhe.status,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Voltar à carteira'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaInfoComprovante extends StatelessWidget {
  const _LinhaInfoComprovante({
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
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
