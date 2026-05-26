// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Painel do Order Book — seções venda/compra com AnimatedList e FABs.

import 'package:flutter/material.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../navigation/mescla_material_route.dart';
import '../../theme/app_colors.dart';
import '../models/ordem_model.dart';
import '../screens/comprar_do_mercado_screen.dart';
import '../screens/comprar_oferta_screen.dart';
import '../screens/criar_ordem_screen.dart';
import '../screens/minhas_ordens_screen.dart';
import '../services/balcao_order_service.dart';
import '../utils/balcao_sort.dart';

/// Livro de ordens P2P para uma startup (aba "Order Book" na mesa).
class OrderBookPanel extends StatelessWidget {
  const OrderBookPanel({
    super.key,
    required this.startupId,
    required this.startupName,
    required this.tokenSigla,
    required this.precoOficialBrl,
  });

  final String startupId;
  final String startupName;
  final String tokenSigla;
  final double precoOficialBrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // StreamBuilder → bubble sort → AnimatedList (vendas)
        StreamBuilder<List<OrdemModel>>(
          stream: BalcaoOrderService.watchSellOrders(startupId),
          builder: (context, sellSnap) {
            if (sellSnap.connectionState == ConnectionState.waiting &&
                !sellSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final vendas = bubbleSortOrdens(sellSnap.data ?? const []);

            return StreamBuilder<List<OrdemModel>>(
              stream: BalcaoOrderService.watchBuyOrders(startupId),
              builder: (context, buySnap) {
                if (buySnap.connectionState == ConnectionState.waiting &&
                    !buySnap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final compras = bubbleSortOrdens(buySnap.data ?? const []);

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MesclaMaterialRoute.fadeSlide(
                                (_) => const MinhasOrdensScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.list_alt_outlined, color: scheme.primary),
                          label: Text(
                            'Minhas ordens',
                            style: TextStyle(color: scheme.primary),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _SecaoOrdens(
                          titulo: 'VENDA',
                          ordens: vendas,
                          colunaTerceira: 'Vendedor',
                          tintColor: scheme.errorContainer.withValues(alpha: 0.35),
                          theme: theme,
                          scheme: scheme,
                          startupId: startupId,
                          startupName: startupName,
                          tokenSigla: tokenSigla,
                          // Só linhas de venda abrem o ecrã de compra P2P.
                          linhasTocaveis: true,
                        ),
                      ),
                      _DivisorPrecoOficial(
                        precoOficialBrl: precoOficialBrl,
                        theme: theme,
                        scheme: scheme,
                      ),
                      Expanded(
                        child: _SecaoOrdens(
                          titulo: 'COMPRA',
                          ordens: compras,
                          colunaTerceira: 'Comprador',
                          tintColor: scheme.primaryContainer.withValues(alpha: 0.35),
                          theme: theme,
                          scheme: scheme,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Acesso às ofertas de venda já publicadas no livro.
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MesclaMaterialRoute.fadeSlide(
                              (_) => ComprarDoMercadoScreen(
                                startupId: startupId,
                                startupName: startupName,
                                tokenSigla: tokenSigla,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.primary,
                          side: BorderSide(color: scheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Comprar ofertas abertas'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _abrirCriarOrdem(
                                context,
                                tipo: TipoOrdem.venda.firestoreValue,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Ordem de Venda'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.error,
                                side: BorderSide(color: scheme.error),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _abrirCriarOrdem(
                                context,
                                tipo: TipoOrdem.compra.firestoreValue,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Ordem de Compra'),
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _abrirCriarOrdem(BuildContext context, {required String tipo}) {
    Navigator.of(context).push<void>(
      MesclaMaterialRoute.fadeSlide(
        (_) => CriarOrdemScreen(
          startupId: startupId,
          startupName: startupName,
          tokenSigla: tokenSigla,
          tipo: tipo,
          precoOficialBrl: precoOficialBrl > 0 ? precoOficialBrl : null,
        ),
      ),
    );
  }
}

class _DivisorPrecoOficial extends StatelessWidget {
  const _DivisorPrecoOficial({
    required this.precoOficialBrl,
    required this.theme,
    required this.scheme,
  });

  final double precoOficialBrl;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final precoTxt = precoOficialBrl > 1e-9 ? formatBrl(precoOficialBrl) : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Preço oficial: $precoTxt',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}

/// Secção do livro (venda ou compra) — lista reactiva ao stream Firestore.
class _SecaoOrdens extends StatelessWidget {
  const _SecaoOrdens({
    required this.titulo,
    required this.ordens,
    required this.colunaTerceira,
    required this.tintColor,
    required this.theme,
    required this.scheme,
    this.startupId,
    this.startupName,
    this.tokenSigla,
    this.linhasTocaveis = false,
  });

  final String titulo;
  final List<OrdemModel> ordens;
  final String colunaTerceira;
  final Color tintColor;
  final ThemeData theme;
  final ColorScheme scheme;
  final String? startupId;
  final String? startupName;
  final String? tokenSigla;
  final bool linhasTocaveis;

  void _abrirComprarOferta(BuildContext context, OrdemModel ordem) {
    final sid = startupId?.trim() ?? '';
    final nome = startupName?.trim() ?? '';
    final sigla = tokenSigla?.trim() ?? '';
    if (sid.isEmpty || nome.isEmpty) return;

    Navigator.of(context).push<void>(
      MesclaMaterialRoute.fadeSlide(
        (_) => ComprarOfertaScreen(
          oferta: ordem,
          startupName: nome,
          tokenSigla: sigla.isNotEmpty ? sigla : ordem.tokenSigla,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tintColor,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                titulo,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              if (linhasTocaveis) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toque na linha para comprar',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _HeaderColunas(
            theme: theme,
            colunaTerceira: colunaTerceira,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ordens.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma ordem aberta',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: ordens.length,
                    itemBuilder: (context, index) {
                      final ordem = ordens[index];
                      return _LinhaOrdem(
                        key: ValueKey(ordem.orderId),
                        ordem: ordem,
                        colunaTerceira: colunaTerceira,
                        theme: theme,
                        tocavel: linhasTocaveis,
                        onTap: linhasTocaveis
                            ? () => _abrirComprarOferta(context, ordem)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderColunas extends StatelessWidget {
  const _HeaderColunas({
    required this.theme,
    required this.colunaTerceira,
  });

  final ThemeData theme;
  final String colunaTerceira;

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.secondaryLabel(theme),
    );

    return Row(
      children: [
        Expanded(flex: 2, child: Text('Quantidade', style: style)),
        Expanded(flex: 3, child: Text('Preço/Token', style: style)),
        Expanded(flex: 3, child: Text('Total', style: style)),
        Expanded(
          flex: 3,
          child: Text(colunaTerceira, style: style, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _LinhaOrdem extends StatelessWidget {
  const _LinhaOrdem({
    super.key,
    required this.ordem,
    required this.colunaTerceira,
    required this.theme,
    this.tocavel = false,
    this.onTap,
  });

  final OrdemModel ordem;
  final String colunaTerceira;
  final ThemeData theme;
  final bool tocavel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.bodySmall;

    final conteudo = Row(
      children: [
        Expanded(flex: 2, child: Text('${ordem.quantity}', style: style)),
        Expanded(
          flex: 3,
          child: Text(formatBrl(ordem.pricePerToken), style: style),
        ),
        Expanded(
          flex: 3,
          child: Text(formatBrl(ordem.totalValueBrl), style: style),
        ),
        Expanded(
          flex: 3,
          child: Text(
            ordem.displayName,
            style: style,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (!tocavel || onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: conteudo,
      );
    }

    // Linha de venda tocável — abre ecrã de compra da oferta.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: conteudo,
        ),
      ),
    );
  }
}
