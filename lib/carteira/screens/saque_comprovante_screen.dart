// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// **Comprovante** do saque (só visual), no mesmo estilo do detalhe de transação
// do Balcão. Fecha o fluxo com dois [pop] até voltar à Carteira.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../format/carteira_brl.dart';
import '../models/pix_chave_ui.dart';

// --- Ecrã ---------------------------------------------------------------------

/// Resumo fixo após o passo de senha (dados mock de status).
class SaqueComprovanteScreen extends StatelessWidget {
  const SaqueComprovanteScreen({
    super.key,
    required this.valorReais,
    required this.chavePix,
    required this.dataHora,
  });

  final double valorReais;
  final PixChaveUi chavePix;
  final DateTime dataHora;

  static const _padH = 20.0;

  String _dataHoraPtBr(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy às $hh:$min';
  }

  /// Remove este ecrã e o [SacarValorScreen] por baixo, ficando na Carteira.
  void _voltarACarteira(BuildContext context) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.pop();
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
    final chaveMascarada = mascararChavePixComprovante(chavePix.valor);

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
            onPressed: () => _voltarACarteira(context),
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
                'Saque concluído',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PIX · ${chavePix.tipoLabel}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                formatBrl(valorReais),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chave: $chaveMascarada',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
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
                      _LinhaDetalheSaque(
                        rotulo: 'Data e hora',
                        valor: _dataHoraPtBr(dataHora),
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _LinhaDetalheSaque(
                        rotulo: 'Status',
                        valor: 'Concluída (demonstração)',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _voltarACarteira(context),
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

// --- Linha de texto no cartão -------------------------------------------------

class _LinhaDetalheSaque extends StatelessWidget {
  const _LinhaDetalheSaque({
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
