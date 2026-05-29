// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Resultado da callable addBuyOrder (compra P2P ou ordem publicada).

/// Resposta normalizada de [BalcaoOrderService.criarOrdemCompra].
class CompraOrdemResult {
  const CompraOrdemResult({
    required this.matched,
    required this.quantity,
    required this.amountBrl,
    required this.pricePerToken,
    required this.startupName,
    required this.tokenSigla,
  });

  /// `true` quando tokens foram transferidos (compra directa ou match).
  final bool matched;

  final int quantity;
  final double amountBrl;
  final double pricePerToken;
  final String startupName;
  final String tokenSigla;
}
