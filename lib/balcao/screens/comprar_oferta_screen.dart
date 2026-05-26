// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Ecrã para comprar tokens diretamente de uma ordem de venda no Order Book.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../navigation/mescla_material_route.dart';
import '../../theme/app_colors.dart';
import '../models/balcao_operacao_tipo.dart';
import '../models/balcao_transacao.dart';
import '../models/ordem_model.dart';
import '../services/balcao_order_service.dart';
import 'balcao_transacao_detalhe_screen.dart';

/// Compra P2P: o utilizador aceita o preço fixo de uma oferta de venda listada.
class ComprarOfertaScreen extends StatefulWidget {
  const ComprarOfertaScreen({
    super.key,
    required this.oferta,
    required this.startupName,
    required this.tokenSigla,
  });

  /// Ordem de venda aberta escolhida no livro.
  final OrdemModel oferta;

  final String startupName;
  final String tokenSigla;

  @override
  State<ComprarOfertaScreen> createState() => _ComprarOfertaScreenState();
}

class _ComprarOfertaScreenState extends State<ComprarOfertaScreen> {
  final _quantidadeController = TextEditingController();

  bool _comprando = false;

  @override
  void dispose() {
    _quantidadeController.dispose();
    super.dispose();
  }

  int? get _quantidadeParsed {
    final raw = _quantidadeController.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  double get _totalPreview {
    final q = _quantidadeParsed;
    if (q == null || q <= 0) return 0;
    return q * widget.oferta.pricePerToken;
  }

  /// Valida quantidade e saldo BRL livre (descontando escrow P2P).
  String? _validar({required double brlDisponivel}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'Inicie sessão para comprar no Order Book.';
    }
    if (widget.oferta.uid == user.uid) {
      return 'Você não pode comprar a sua própria oferta.';
    }

    final q = _quantidadeParsed;
    if (q == null || q <= 0) {
      return 'Informe uma quantidade de tokens maior que zero.';
    }
    if (q > widget.oferta.quantity) {
      return 'Quantidade maior que a disponível na oferta (${widget.oferta.quantity}).';
    }

    final total = q * widget.oferta.pricePerToken;
    if (total > brlDisponivel + 1e-9) {
      return 'Saldo insuficiente';
    }
    return null;
  }

  Future<void> _confirmarCompra({required double brlDisponivel}) async {
    final erro = _validar(brlDisponivel: brlDisponivel);
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    final q = _quantidadeParsed!;

    setState(() => _comprando = true);
    try {
      final resultado = await BalcaoOrderService.criarOrdemCompra(
        startupId: widget.oferta.startupId,
        quantity: q,
        pricePerToken: widget.oferta.pricePerToken,
        targetSellOrderId: widget.oferta.orderId,
      );
      if (!mounted) return;

      if (resultado.matched) {
        // Comprovante — mesmo ecrã do fluxo Compra Rápida.
        final detalhe = BalcaoTransacaoDetalhe(
          operacao: BalcaoOperacaoTipo.compra,
          nomeToken: widget.tokenSigla.isNotEmpty
              ? widget.tokenSigla
              : resultado.tokenSigla,
          quantidadeTokens: resultado.quantity,
          valorReais: resultado.amountBrl,
          dataHora: DateTime.now(),
          status: 'Concluída',
        );
        Navigator.of(context).pushReplacement(
          MesclaMaterialRoute.fadeSlide<void>(
            (context) => BalcaoTransacaoDetalheScreen(detalhe: detalhe),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ordem de compra publicada. Aguardando contraparte no Order Book.',
          ),
        ),
      );
      Navigator.of(context).pop(false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BalcaoOrderService.messageForUser(e))),
      );
    } finally {
      if (mounted) setState(() => _comprando = false);
    }
  }

  double _readBrlLocked(DocumentSnapshot<Map<String, dynamic>>? snap) {
    final v = snap?.data()?['brlLockedInOrders'];
    return v is num ? v.toDouble() : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final oferta = widget.oferta;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprar oferta'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: user == null
          ? Center(
              child: Text(
                'Inicie sessão para comprar ofertas.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
            )
          : StreamBuilder<double>(
              stream: SimulatedWalletService.watchBrlBalance(user.uid),
              builder: (context, saldoSnap) {
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: SimulatedWalletPaths.walletDoc(user.uid).snapshots(),
                  builder: (context, walletSnap) {
                    final brlBalance = saldoSnap.data ?? 0.0;
                    final brlLocked = _readBrlLocked(walletSnap.data);
                    // BRL reservado em ordens P2P abertas não pode ser reutilizado.
                    final brlDisponivel = brlBalance - brlLocked;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            color: AppColors.themeCardSurface(theme),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: scheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Startup: ${widget.startupName}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Token: ${widget.tokenSigla}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.secondaryLabel(theme),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Vendedor: ${oferta.displayName}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Disponível na oferta: ${oferta.quantity} tokens',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Seu saldo disponível: ${formatBrl(brlDisponivel)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Preço fixo da oferta — não editável pelo comprador.
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Preço por token (R\$)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              formatBrl(oferta.pricePerToken),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _quantidadeController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Quantidade de tokens',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Total da operação: ${formatBrl(_totalPreview)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 28),
                          FilledButton(
                            onPressed: _comprando
                                ? null
                                : () => _confirmarCompra(
                                      brlDisponivel: brlDisponivel,
                                    ),
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _comprando
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Text('Confirmar compra'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
