// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Dados para o ecrã [CarteiraMovimentacaoDetalheScreen] (mesmo padrão visual do
// detalhe do Balcão), construídos a partir do ledger `sim_wallet` ou da lista mock.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../balcao/balcao_format.dart';

/// Resumo imutável para o comprovante “Detalhe da transação” na Carteira.
class CarteiraMovimentacaoDetalhe {
  const CarteiraMovimentacaoDetalhe({
    required this.tituloConclusao,
    required this.subtitulo,
    required this.linhaDestaque,
    required this.linhaDestaqueEmCorPrimaria,
    required this.valorReaisExibicao,
    required this.dataHora,
    this.status = 'Concluída',
  });

  /// Ex.: "Compra concluída", "Saque concluído".
  final String tituloConclusao;

  /// Linha cinza abaixo do título (ex.: "Token WHOP").
  final String subtitulo;

  /// Linha grande (roxo só em operações de token, como no Balcão).
  final String linhaDestaque;

  final bool linhaDestaqueEmCorPrimaria;

  /// Valor em reais já formatado / mascarado pelo ecrã pai.
  final String valorReaisExibicao;

  final DateTime dataHora;

  final String status;

  static DateTime _dataHoraDeLedger(Map<String, dynamic> m) {
    final ts = m['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    return DateTime.now();
  }

  /// A partir de um documento `sim_wallet/{uid}/ledger/*`.
  static CarteiraMovimentacaoDetalhe fromLedger(
    Map<String, dynamic> m, {
    required String Function(double brl) formatarBrl,
  }) {
    final op = m['op'] as String?;
    final headline = (m['headline'] as String?)?.trim() ?? '';
    final amount = (m['amountBrl'] as num?)?.toDouble() ?? 0.0;
    final dt = _dataHoraDeLedger(m);
    final valorTxt = formatarBrl(amount);

    final tokens = (m['tokensQuantity'] as num?)?.toDouble();
    final sigla = (m['tokenSigla'] as String?)?.trim();
    final startupName = (m['startupName'] as String?)?.trim();

    switch (op) {
      case 'trade_buy':
        final nomeTok =
            (sigla != null && sigla.isNotEmpty) ? sigla : (startupName ?? 'Token');
        return CarteiraMovimentacaoDetalhe(
          tituloConclusao: 'Compra concluída',
          subtitulo: 'Token $nomeTok',
          linhaDestaque: '${formatQuantidadeTokensBr(tokens ?? 0)} tokens',
          linhaDestaqueEmCorPrimaria: true,
          valorReaisExibicao: valorTxt,
          dataHora: dt,
        );
      case 'trade_sell':
        final nomeTok =
            (sigla != null && sigla.isNotEmpty) ? sigla : (startupName ?? 'Token');
        return CarteiraMovimentacaoDetalhe(
          tituloConclusao: 'Venda concluída',
          subtitulo: 'Token $nomeTok',
          linhaDestaque: '${formatQuantidadeTokensBr(tokens ?? 0)} tokens',
          linhaDestaqueEmCorPrimaria: true,
          valorReaisExibicao: valorTxt,
          dataHora: dt,
        );
      case 'withdraw_pix_simulated':
        final tipo = (m['pixTipo'] as String?)?.trim() ?? 'PIX';
        final hint = (m['pixDestHint'] as String?)?.trim() ?? '';
        return CarteiraMovimentacaoDetalhe(
          tituloConclusao: 'Saque concluído',
          subtitulo: headline.isNotEmpty ? headline : 'Saque via PIX',
          linhaDestaque: hint.isNotEmpty ? hint : 'Chave $tipo',
          linhaDestaqueEmCorPrimaria: false,
          valorReaisExibicao: valorTxt,
          dataHora: dt,
        );
      case 'credit_pix_simulated':
        return CarteiraMovimentacaoDetalhe(
          tituloConclusao: 'Crédito concluído',
          subtitulo: headline.isNotEmpty ? headline : 'Crédito PIX simulado',
          linhaDestaque: 'Entrada na carteira (simulação)',
          linhaDestaqueEmCorPrimaria: false,
          valorReaisExibicao: valorTxt,
          dataHora: dt,
        );
      default:
        final dirIn = (m['dir'] as String?) == 'in';
        return CarteiraMovimentacaoDetalhe(
          tituloConclusao: dirIn ? 'Entrada concluída' : 'Saída concluída',
          subtitulo: headline.isNotEmpty ? headline : 'Movimentação',
          linhaDestaque: _ledgerOpLegivel(op),
          linhaDestaqueEmCorPrimaria: false,
          valorReaisExibicao: valorTxt,
          dataHora: dt,
        );
    }
  }

  /// Lista mock do convidado (sem documento Firestore).
  static CarteiraMovimentacaoDetalhe fromConvidadoMock({
    required bool entrada,
    required String detalheCaps,
    required String dataDdMmYyyy,
    required double valorNumerico,
    required String Function(double brl) formatarBrl,
  }) {
    final dt = _parseDataBr(dataDdMmYyyy);
    final caps = detalheCaps.toUpperCase();
    final valorTxt = formatarBrl(valorNumerico);

    if (caps.contains('CREDITO') && caps.contains('PIX')) {
      return CarteiraMovimentacaoDetalhe(
        tituloConclusao: 'Crédito concluído',
        subtitulo: detalheCaps,
        linhaDestaque: 'Crédito PIX (demonstração)',
        linhaDestaqueEmCorPrimaria: false,
        valorReaisExibicao: valorTxt,
        dataHora: dt,
      );
    }
    if (caps.contains('COMPRA') && caps.contains('TOKEN')) {
      return CarteiraMovimentacaoDetalhe(
        tituloConclusao: 'Compra concluída',
        subtitulo: 'Token (demonstração)',
        linhaDestaque: '${formatQuantidadeTokensBr(0)} tokens',
        linhaDestaqueEmCorPrimaria: true,
        valorReaisExibicao: valorTxt,
        dataHora: dt,
      );
    }
    if (caps.contains('DIVIDENDO')) {
      return CarteiraMovimentacaoDetalhe(
        tituloConclusao: 'Dividendos creditados',
        subtitulo: detalheCaps,
        linhaDestaque: 'Rendimento na carteira (demo)',
        linhaDestaqueEmCorPrimaria: false,
        valorReaisExibicao: valorTxt,
        dataHora: dt,
      );
    }
    if (caps.contains('TAXA')) {
      return CarteiraMovimentacaoDetalhe(
        tituloConclusao: 'Pagamento concluído',
        subtitulo: detalheCaps,
        linhaDestaque: 'Tarifa da plataforma (demo)',
        linhaDestaqueEmCorPrimaria: false,
        valorReaisExibicao: valorTxt,
        dataHora: dt,
      );
    }
    if (entrada) {
      return CarteiraMovimentacaoDetalhe(
        tituloConclusao: 'Entrada concluída',
        subtitulo: detalheCaps,
        linhaDestaque: 'Movimentação na carteira (demo)',
        linhaDestaqueEmCorPrimaria: false,
        valorReaisExibicao: valorTxt,
        dataHora: dt,
      );
    }
    return CarteiraMovimentacaoDetalhe(
      tituloConclusao: 'Saída concluída',
      subtitulo: detalheCaps,
      linhaDestaque: 'Movimentação na carteira (demo)',
      linhaDestaqueEmCorPrimaria: false,
      valorReaisExibicao: valorTxt,
      dataHora: dt,
    );
  }

  static DateTime _parseDataBr(String s) {
    final parts = s.split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0].trim());
      final month = int.tryParse(parts[1].trim());
      final y = int.tryParse(parts[2].trim());
      if (d != null && month != null && y != null) {
        return DateTime(y, month, d, 12, 0);
      }
    }
    return DateTime.now();
  }

  static String _ledgerOpLegivel(String? op) {
    switch (op) {
      case 'credit_pix_simulated':
        return 'Crédito PIX (simulado)';
      case 'withdraw_pix_simulated':
        return 'Saque PIX (simulado)';
      case 'trade_buy':
        return 'Compra de tokens';
      case 'trade_sell':
        return 'Venda de tokens';
      default:
        final t = op?.trim();
        return (t != null && t.isNotEmpty) ? t : 'Movimentação';
    }
  }
}
