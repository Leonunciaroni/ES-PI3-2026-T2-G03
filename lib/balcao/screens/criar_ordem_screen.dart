// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Formulário para publicar ordem de compra ou venda no Order Book P2P.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../theme/app_colors.dart';
import '../balcao_official_price.dart';
import '../models/ordem_model.dart';
import '../services/balcao_order_service.dart';

/// Ecrã para criar ordem limitada no Order Book.
class CriarOrdemScreen extends StatefulWidget {
  const CriarOrdemScreen({
    super.key,
    required this.startupId,
    required this.startupName,
    required this.tokenSigla,
    required this.tipo,
    this.precoOficialBrl,
  });

  final String startupId;
  final String startupName;
  final String tokenSigla;

  /// `buy` ou `sell` (valores Firestore).
  final String tipo;

  /// Cotação já conhecida da mesa (opcional).
  final double? precoOficialBrl;

  bool get isCompra => tipo.trim().toLowerCase() == TipoOrdem.compra.firestoreValue;

  @override
  State<CriarOrdemScreen> createState() => _CriarOrdemScreenState();
}

class _CriarOrdemScreenState extends State<CriarOrdemScreen> {
  final _quantidadeController = TextEditingController();
  final _precoController = TextEditingController();

  bool _publicando = false;
  double? _precoOficialCarregado;

  @override
  void initState() {
    super.initState();
    _precoOficialCarregado = widget.precoOficialBrl;
    _carregarPrecoOficialSeNecessario();
  }

  Future<void> _carregarPrecoOficialSeNecessario() async {
    if (_precoOficialCarregado != null && _precoOficialCarregado! > 0) return;
    final p = await fetchPrecoTokenOficialBrl(widget.startupId);
    if (!mounted) return;
    setState(() => _precoOficialCarregado = p);
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    _precoController.dispose();
    super.dispose();
  }

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

  String? _validar({
    required int tokensDisponiveis,
    required double brlDisponivel,
  }) {
    final q = _quantidadeParsed;
    final p = _precoParsed;

    if (q == null || q <= 0) {
      return 'Informe uma quantidade de tokens maior que zero.';
    }
    if (p == null || p <= 0) {
      return 'Informe um preço por token maior que zero.';
    }

    if (widget.isCompra) {
      final total = q * p;
      if (total > brlDisponivel + 1e-9) {
        return 'Saldo insuficiente';
      }
    } else {
      if (q > tokensDisponiveis) {
        return 'Você não possui tokens suficientes';
      }
    }
    return null;
  }

  Future<void> _publicar({
    required int tokensDisponiveis,
    required double brlDisponivel,
  }) async {
    final erro = _validar(
      tokensDisponiveis: tokensDisponiveis,
      brlDisponivel: brlDisponivel,
    );
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    final q = _quantidadeParsed!;
    final p = _precoParsed!;

    setState(() => _publicando = true);
    try {
      if (widget.isCompra) {
        await BalcaoOrderService.criarOrdemCompra(
          startupId: widget.startupId,
          quantity: q,
          pricePerToken: p,
        );
      } else {
        await BalcaoOrderService.criarOrdemVenda(
          startupId: widget.startupId,
          quantity: q,
          pricePerToken: p,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordem publicada com sucesso!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BalcaoOrderService.messageForUser(e))),
      );
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final titulo = widget.isCompra
        ? 'Criar Ordem de Compra'
        : 'Criar Ordem de Venda';

    final precoOficial = _precoOficialCarregado;

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: user == null
          ? Center(
              child: Text(
                'Inicie sessão para publicar ordens.',
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
                        widget.startupId,
                      ),
                      builder: (context, tokensSnap) {
                        return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          stream: SimulatedWalletPaths.positionsCol(user.uid)
                              .doc(widget.startupId)
                              .snapshots(),
                          builder: (context, posSnap) {
                            final brlBalance = saldoSnap.data ?? 0.0;
                            final brlLocked = _readBrlLocked(walletSnap.data);
                            final brlDisponivel = brlBalance - brlLocked;

                            final tokensHeldExact = tokensSnap.data ?? 0.0;
                            final tokensLocked =
                                _readTokensLocked(posSnap.data);
                            // Só tokens inteiros são negociáveis; floor evita oversell em saldos legados fracionários.
                            final tokensDisponiveis =
                                tokensHeldExact.floor() - tokensLocked;

                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _InfoCard(
                                    theme: theme,
                                    scheme: scheme,
                                    startupName: widget.startupName,
                                    precoOficial: precoOficial,
                                    isCompra: widget.isCompra,
                                    tokensDisponiveis: tokensDisponiveis,
                                    brlDisponivel: brlDisponivel,
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
                                    keyboardType: const TextInputType.numberWithOptions(
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
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  FilledButton(
                                    onPressed: _publicando
                                        ? null
                                        : () => _publicar(
                                              tokensDisponiveis: tokensDisponiveis,
                                              brlDisponivel: brlDisponivel,
                                            ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: scheme.primary,
                                      foregroundColor: scheme.onPrimary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _publicando
                                        ? SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: scheme.onPrimary,
                                            ),
                                          )
                                        : const Text('Publicar Ordem'),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.theme,
    required this.scheme,
    required this.startupName,
    required this.precoOficial,
    required this.isCompra,
    required this.tokensDisponiveis,
    required this.brlDisponivel,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final String startupName;
  final double? precoOficial;
  final bool isCompra;
  final int tokensDisponiveis;
  final double brlDisponivel;

  @override
  Widget build(BuildContext context) {
    final precoTxt = precoOficial != null && precoOficial! > 0
        ? formatBrl(precoOficial!)
        : '—';

    return Card(
      color: AppColors.themeCardSurface(theme),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Startup: $startupName',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preço oficial atual: $precoTxt/token',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryLabel(theme),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCompra
                  ? 'Seu saldo disponível: ${formatBrl(brlDisponivel)}'
                  : 'Seus tokens disponíveis: $tokensDisponiveis tokens',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
