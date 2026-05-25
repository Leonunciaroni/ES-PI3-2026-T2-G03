// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Lista ofertas de venda abertas para comprar tokens já no mercado (Order Book).

import 'package:flutter/material.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../navigation/mescla_material_route.dart';
import '../../theme/app_colors.dart';
import '../models/ordem_model.dart';
import '../services/balcao_order_service.dart';
import '../utils/balcao_sort.dart';
import 'comprar_oferta_screen.dart';

/// Ecrã para comprar tokens de ofertas já publicadas no Order Book.
class ComprarDoMercadoScreen extends StatelessWidget {
  const ComprarDoMercadoScreen({
    super.key,
    required this.startupId,
    required this.startupName,
    required this.tokenSigla,
  });

  final String startupId;
  final String startupName;
  final String tokenSigla;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ofertas abertas'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<OrdemModel>>(
        stream: BalcaoOrderService.watchSellOrders(startupId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ofertas = bubbleSortOrdens(snap.data ?? const <OrdemModel>[]);

          if (ofertas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não há ofertas de venda abertas no momento.\n'
                  'Publique uma ordem de compra ou volte mais tarde.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
              ),
            );
          }

          // Melhor preço = primeira oferta após ordenação (menor preço/token).
          final melhor = ofertas.first;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Resumo da melhor oferta disponível no mercado.
              Card(
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Melhor oferta disponível',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatBrl(melhor.pricePerToken)}/token · '
                        '${melhor.quantity} tokens · '
                        'vendedor: ${melhor.displayName}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _abrirCompra(context, melhor),
                        child: const Text('Comprar melhor oferta'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Todas as ofertas de venda',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...ofertas.map(
                (oferta) => _OfertaCard(
                  oferta: oferta,
                  theme: theme,
                  scheme: scheme,
                  onComprar: () => _abrirCompra(context, oferta),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Abre o formulário de compra com preço fixo da oferta escolhida.
  void _abrirCompra(BuildContext context, OrdemModel oferta) {
    Navigator.of(context).push<void>(
      MesclaMaterialRoute.fadeSlide(
        (_) => ComprarOfertaScreen(
          oferta: oferta,
          startupName: startupName,
          tokenSigla: tokenSigla.isNotEmpty ? tokenSigla : oferta.tokenSigla,
        ),
      ),
    );
  }
}

class _OfertaCard extends StatelessWidget {
  const _OfertaCard({
    required this.oferta,
    required this.theme,
    required this.scheme,
    required this.onComprar,
  });

  final OrdemModel oferta;
  final ThemeData theme;
  final ColorScheme scheme;
  final VoidCallback onComprar;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.themeCardSurface(theme),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oferta.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${oferta.quantity} tokens · ${formatBrl(oferta.pricePerToken)}/token',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    'Total: ${formatBrl(oferta.totalValueBrl)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onComprar,
              child: const Text('Comprar'),
            ),
          ],
        ),
      ),
    );
  }
}
