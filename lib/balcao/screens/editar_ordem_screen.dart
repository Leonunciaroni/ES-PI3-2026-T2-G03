// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Formulário para editar ordem aberta (quantidade e preço) no Order Book.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../theme/app_colors.dart';
import '../models/ordem_model.dart';
import '../services/balcao_order_service.dart';

/// Permite alterar quantidade e preço de uma ordem aberta do investidor.
class EditarOrdemScreen extends StatefulWidget {
  const EditarOrdemScreen({super.key, required this.ordem});

  final OrdemModel ordem;

  @override
  State<EditarOrdemScreen> createState() => _EditarOrdemScreenState();
}

class _EditarOrdemScreenState extends State<EditarOrdemScreen> {
  late final TextEditingController _quantidadeController;
  late final TextEditingController _precoController;

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _quantidadeController =
        TextEditingController(text: '${widget.ordem.quantity}');
    _precoController = TextEditingController(
      text: widget.ordem.pricePerToken.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  bool get _isCompra => widget.ordem.tipo == TipoOrdem.compra;

  int? get _quantidadeParsed {
    final raw = _quantidadeController.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  double? get _precoParsed {
    final raw = _precoController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  double get _totalPreview {
    final q = _quantidadeParsed;
    final p = _precoParsed;
    if (q == null || p == null || q <= 0 || p <= 0) return 0;
    return q * p;
  }

  /// Valida campos; considera escrow já reservado por esta ordem.
  String? _validar({
    required int tokensDisponiveisComOrdem,
    required double brlDisponivelComOrdem,
  }) {
    final q = _quantidadeParsed;
    final p = _precoParsed;

    if (q == null || q <= 0) {
      return 'Informe uma quantidade de tokens maior que zero.';
    }
    if (p == null || p <= 0) {
      return 'Informe um preço por token maior que zero.';
    }

    if (_isCompra) {
      final total = q * p;
      if (total > brlDisponivelComOrdem + 1e-9) {
        return 'Saldo insuficiente';
      }
    } else {
      if (q > tokensDisponiveisComOrdem) {
        return 'Você não possui tokens suficientes';
      }
    }
    return null;
  }

  Future<void> _salvar({
    required int tokensDisponiveisComOrdem,
    required double brlDisponivelComOrdem,
  }) async {
    final erro = _validar(
      tokensDisponiveisComOrdem: tokensDisponiveisComOrdem,
      brlDisponivelComOrdem: brlDisponivelComOrdem,
    );
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    final q = _quantidadeParsed!;
    final p = _precoParsed!;
    final ordem = widget.ordem;

    setState(() => _salvando = true);
    try {
      await BalcaoOrderService.editarOrdem(
        startupId: ordem.startupId,
        orderId: ordem.orderId,
        tipo: ordem.tipo.firestoreValue,
        quantity: q,
        pricePerToken: p,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordem atualizada com sucesso!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BalcaoOrderService.messageForUser(e))),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final ordem = widget.ordem;
    final titulo =
        _isCompra ? 'Editar ordem de compra' : 'Editar ordem de venda';

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: user == null
          ? Center(
              child: Text(
                'Inicie sessão para editar ordens.',
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
                    return StreamBuilder<double>(
                      stream: SimulatedWalletService.watchTokensHeld(
                        user.uid,
                        ordem.startupId,
                      ),
                      builder: (context, tokensSnap) {
                        return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          stream: SimulatedWalletPaths.positionsCol(user.uid)
                              .doc(ordem.startupId)
                              .snapshots(),
                          builder: (context, posSnap) {
                            final brlBalance = saldoSnap.data ?? 0.0;
                            final brlLocked = _readBrlLocked(walletSnap.data);
                            // Devolve o BRL desta ordem ao calcular o limite.
                            final brlDisponivelComOrdem = brlBalance -
                                brlLocked +
                                ordem.totalValueBrl;

                            final tokensHeldExact = tokensSnap.data ?? 0.0;
                            final tokensLocked =
                                _readTokensLocked(posSnap.data);
                            final tokensDisponiveisComOrdem =
                                tokensHeldExact.floor() -
                                    tokensLocked +
                                    ordem.quantity;

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
                                        color: scheme.outlineVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ordem.startupName,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _isCompra
                                                ? 'Saldo disponível (com esta ordem): '
                                                    '${formatBrl(brlDisponivelComOrdem)}'
                                                : 'Tokens disponíveis (com esta ordem): '
                                                    '$tokensDisponiveisComOrdem',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: scheme.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
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
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _precoController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Preço por token (R\$)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Total da operação: ${formatBrl(_totalPreview)}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  FilledButton(
                                    onPressed: _salvando
                                        ? null
                                        : () => _salvar(
                                              tokensDisponiveisComOrdem:
                                                  tokensDisponiveisComOrdem,
                                              brlDisponivelComOrdem:
                                                  brlDisponivelComOrdem,
                                            ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _salvando
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Salvar alterações'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  double _readBrlLocked(DocumentSnapshot<Map<String, dynamic>>? snap) {
    final v = snap?.data()?['brlLockedInOrders'];
    return v is num ? v.toDouble() : 0.0;
  }

  int _readTokensLocked(DocumentSnapshot<Map<String, dynamic>>? snap) {
    final v = snap?.data()?['tokensLockedInOrders'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
}
