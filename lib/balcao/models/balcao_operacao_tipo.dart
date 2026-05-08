// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tipo de operação no Balcão (compra ou venda de tokens).
// Enum simples: o compilador obriga a tratar os dois casos em [switch].

/// Identifica se o fluxo atual é de **compra** ou **venda** de tokens.
///
/// Usado na tela de quantidade, na de senha e no resumo do detalhe
/// da transação (§5.3 do documento de visão MesclaInvest).
enum BalcaoOperacaoTipo {
  /// Aquisição de tokens com valor em reais.
  compra,

  /// Liquidação parcial ou total de tokens.
  venda,
}

extension BalcaoOperacaoTipoX on BalcaoOperacaoTipo {
  /// Rótulo curto para botões e títulos (ex.: "Comprar").
  String get verboInfinitivo {
    switch (this) {
      case BalcaoOperacaoTipo.compra:
        return 'Comprar';
      case BalcaoOperacaoTipo.venda:
        return 'Vender';
    }
  }
}
