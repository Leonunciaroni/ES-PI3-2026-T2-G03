// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Lista ordens abertas do utilizador com opção de cancelamento.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../theme/app_colors.dart';
import '../models/ordem_model.dart';
import '../services/balcao_order_service.dart';

/// Ecrã opcional com ordens abertas do investidor logado.
class MinhasOrdensScreen extends StatelessWidget {
  const MinhasOrdensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas ordens'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: user == null
          ? Center(
              child: Text(
                'Inicie sessão para ver suas ordens.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
            )
          : StreamBuilder<List<OrdemModel>>(
              stream: BalcaoOrderService.watchMinhasOrdens(user.uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final ordens = snap.data ?? const <OrdemModel>[];

                if (ordens.isEmpty) {
                  return Center(
                    child: Text(
                      'Você não tem ordens abertas.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: ordens.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final ordem = ordens[index];
                    return _OrdemCard(
                      ordem: ordem,
                      theme: theme,
                      scheme: scheme,
                      onCancelar: () => _cancelar(context, ordem),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _cancelar(BuildContext context, OrdemModel ordem) async {
    try {
      await BalcaoOrderService.cancelarOrdem(
        startupId: ordem.startupId,
        orderId: ordem.orderId,
        tipo: ordem.tipo.firestoreValue,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordem cancelada.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BalcaoOrderService.messageForUser(e))),
      );
    }
  }
}

class _OrdemCard extends StatelessWidget {
  const _OrdemCard({
    required this.ordem,
    required this.theme,
    required this.scheme,
    required this.onCancelar,
  });

  final OrdemModel ordem;
  final ThemeData theme;
  final ColorScheme scheme;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final isVenda = ordem.tipo == TipoOrdem.venda;
    final tipoLabel = isVenda ? 'Venda' : 'Compra';

    Color chipBg;
    Color chipFg;
    switch (ordem.status) {
      case StatusOrdem.aberta:
        chipBg = scheme.primaryContainer;
        chipFg = scheme.onPrimaryContainer;
      case StatusOrdem.executada:
        chipBg = scheme.tertiaryContainer;
        chipFg = scheme.onTertiaryContainer;
      case StatusOrdem.cancelada:
        chipBg = scheme.surfaceContainerHighest;
        chipFg = scheme.onSurfaceVariant;
    }

    final statusLabel = switch (ordem.status) {
      StatusOrdem.aberta => 'Aberta',
      StatusOrdem.executada => 'Executada',
      StatusOrdem.cancelada => 'Cancelada',
    };

    return Card(
      color: AppColors.themeCardSurface(theme),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$tipoLabel · ${ordem.startupName}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  label: Text(statusLabel, style: TextStyle(color: chipFg)),
                  backgroundColor: chipBg,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${ordem.quantity} tokens · ${formatBrl(ordem.pricePerToken)}/token',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              'Total: ${formatBrl(ordem.totalValueBrl)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryLabel(theme),
              ),
            ),
            if (ordem.podeCancelar) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancelar,
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
