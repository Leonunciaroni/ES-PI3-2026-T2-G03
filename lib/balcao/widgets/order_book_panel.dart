// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Painel do Order Book — seções venda/compra com AnimatedList e FABs.

import 'package:flutter/material.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../navigation/mescla_material_route.dart';
import '../../theme/app_colors.dart';
import '../models/ordem_model.dart';
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

/// Secção do livro (venda ou compra) com [AnimatedList].
class _SecaoOrdens extends StatefulWidget {
  const _SecaoOrdens({
    required this.titulo,
    required this.ordens,
    required this.colunaTerceira,
    required this.tintColor,
    required this.theme,
    required this.scheme,
  });

  final String titulo;
  final List<OrdemModel> ordens;
  final String colunaTerceira;
  final Color tintColor;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  State<_SecaoOrdens> createState() => _SecaoOrdensState();
}

class _SecaoOrdensState extends State<_SecaoOrdens> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<OrdemModel> _items = <OrdemModel>[];

  @override
  void initState() {
    super.initState();
    _items.addAll(widget.ordens);
  }

  @override
  void didUpdateWidget(covariant _SecaoOrdens oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sincronizarLista(widget.ordens);
  }

  /// Diff por [orderId]: remove itens ausentes e insere novos com animação.
  void _sincronizarLista(List<OrdemModel> novas) {
    final idsNovos = novas.map((o) => o.orderId).toSet();

    for (var i = _items.length - 1; i >= 0; i--) {
      if (!idsNovos.contains(_items[i].orderId)) {
        final removido = _items.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildLinha(removido, animation, saindo: true),
          duration: const Duration(milliseconds: 250),
        );
      }
    }

    for (final ordem in novas) {
      final idx = _items.indexWhere((o) => o.orderId == ordem.orderId);
      if (idx >= 0) {
        _items[idx] = ordem;
      } else {
        final insertAt = _items.length;
        _items.add(ordem);
        _listKey.currentState?.insertItem(
          insertAt,
          duration: const Duration(milliseconds: 250),
        );
      }
    }

    // Reordena silenciosamente conforme bubble sort do pai.
    _items
      ..clear()
      ..addAll(novas);

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.tintColor,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.titulo,
            style: widget.theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _HeaderColunas(
            theme: widget.theme,
            colunaTerceira: widget.colunaTerceira,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: widget.ordens.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma ordem aberta',
                      style: widget.theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryLabel(widget.theme),
                      ),
                    ),
                  )
                : AnimatedList(
                    key: _listKey,
                    initialItemCount: _items.length,
                    itemBuilder: (context, index, animation) {
                      if (index >= _items.length) {
                        return const SizedBox.shrink();
                      }
                      return _buildLinha(_items[index], animation);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinha(
    OrdemModel ordem,
    Animation<double> animation, {
    bool saindo = false,
  }) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: _LinhaOrdem(
          ordem: ordem,
          colunaTerceira: widget.colunaTerceira,
          theme: widget.theme,
        ),
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
        Expanded(flex: 3, child: Text(colunaTerceira, style: style, textAlign: TextAlign.end)),
      ],
    );
  }
}

class _LinhaOrdem extends StatelessWidget {
  const _LinhaOrdem({
    required this.ordem,
    required this.colunaTerceira,
    required this.theme,
  });

  final OrdemModel ordem;
  final String colunaTerceira;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('${ordem.quantity}', style: style)),
          Expanded(
            flex: 3,
            child: Text(formatBrl(ordem.pricePerToken), style: style),
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
      ),
    );
  }
}
