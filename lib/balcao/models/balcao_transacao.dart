// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Modelos de dados mínimos para a lista "do dia" e para o ecrã de detalhe
// após validar a senha. São **imutáveis** (`final`) e sem lógica de negócio
// pesada — adequados ao PI3.

import 'balcao_operacao_tipo.dart';

/// Uma linha da lista de transações do dia na mesa do Balcão.
class BalcaoTransacaoDia {
  const BalcaoTransacaoDia({
    required this.tipo,
    required this.resumo,
    required this.valorReais,
    this.dataHora,
  });

  final BalcaoOperacaoTipo tipo;

  /// Texto curto de contexto (ex.: "Balcão de negociação"), **sem** endereço de rede.
  final String resumo;

  /// Valor absoluto em reais.
  final double valorReais;

  /// Quando veio do `ledger` Firestore ([null] nos mocks/demo).
  final DateTime? dataHora;
}

/// Dados mostrados no ecrã de detalhe após operação bem-sucedida.
class BalcaoTransacaoDetalhe {
  const BalcaoTransacaoDetalhe({
    required this.operacao,
    required this.nomeToken,
    required this.quantidadeTokens,
    required this.valorReais,
    required this.dataHora,
    required this.status,
  });

  final BalcaoOperacaoTipo operacao;

  /// Nome ou sigla exibida ao utilizador (ex.: "GFLO" ou nome da startup).
  final String nomeToken;
  final double quantidadeTokens;
  final double valorReais;
  final DateTime dataHora;

  /// Texto fixo de demo (ex.: "Concluída").
  final String status;
}
