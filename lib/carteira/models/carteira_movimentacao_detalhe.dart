// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Dados para o ecrã [CarteiraMovimentacaoDetalheScreen] — layout **Comprovante**
// (título de estado, subtítulo, valor em destaque roxo, linha opcional tipo
// “Chave: …”, cartão Informações), alinhado a [SaqueComprovanteScreen].

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../balcao/balcao_format.dart';

/// Resumo imutável para o comprovante na Carteira (“Ver detalhes”).
class CarteiraMovimentacaoDetalhe {
  const CarteiraMovimentacaoDetalhe({
    required this.tituloConclusao,
    required this.subtitulo,
    required this.valorReaisExibicao,
    required this.dataHora,
    this.linhaRodapeOpcional,
    this.status = 'Concluída (demonstração)',
  });

  /// Ex.: "Saque concluído", "Compra concluída".
  final String tituloConclusao;

  /// Linha cinza sob o título (ex.: "PIX · Telefone", "Token WHOP").
  final String subtitulo;

  /// Valor em reais já formatado / mascarado (mostrado em roxo, como o comprovante).
  final String valorReaisExibicao;

  final DateTime dataHora;

  /// Texto pequeno cinza sob o valor (ex.: "Chave: 199…13"); `null` omite a linha.
  final String? linhaRodapeOpcional;

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
          valorReaisExibicao: valorTxt,
          dataHora: dt,
          linhaRodapeOpcional:
              'Quantidade: ${formatQuantidadeTokensBr(tokens ?? 0)} tokens',
        );
      case 'trade_sell':
        final nomeTok =
            (sigla != null && sigla.isNotEmpty) ? sigla : (startupName ?? 'Token');
        return CarteiraMovimentacaoDetalhe(
          tituloConclusao: 'Venda concluída',
          subtitulo: 'Token $nomeTok',
          valorReaisExibicao: valorTxt,
          dataHora: dt,
          linhaRodapeOpcional:
              'Quantidade: ${formatQuantidadeTokensBr(tokens ?? 0)} tokens',
        );
      case 'withdraw_pix_simulated':
        final tipo = (m['pixTipo'] as String?)?.trim() ?? 'PIX';
        final hint = (m['pixDestHint'] as String?)?.trim() ?? '';
        return CarteiraMovimentacaoDetalhe(
          tituloConclusao: 'Saque concluído',
          subtitulo: 'PIX · $tipo',
          valorReaisExibicao: valorTxt,
          dataHora: dt,
          linhaRodapeOpcional:
              hint.isNotEmpty ? 'Chave: $hint' : 'Chave: —',
        );
      case 'credit_pix_simulated':
        return CarteiraMovimentacaoDetalhe(
          tituloConclusao: 'Crédito concluído',
          subtitulo: headline.isNotEmpty ? headline : 'PIX · Crédito simulado',
          valorReaisExibicao: valorTxt,
          dataHora: dt,
          linhaRodapeOpcional: 'Entrada na carteira (simulação)',
        );
      default:
        final dirIn = (m['dir'] as String?) == 'in';
        final leg = _ledgerOpLegivel(op);
        return CarteiraMovimentacaoDetalhe(
          tituloConclusao: dirIn ? 'Entrada concluída' : 'Saída concluída',
          subtitulo: headline.isNotEmpty ? headline : leg,
          valorReaisExibicao: valorTxt,
          dataHora: dt,
          linhaRodapeOpcional: null,
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
        subtitulo: 'PIX · $detalheCaps',
        valorReaisExibicao: valorTxt,
        dataHora: dt,
        linhaRodapeOpcional: 'Crédito simulado (demonstração)',
      );
    }
    if (caps.contains('COMPRA') && caps.contains('TOKEN')) {
      return CarteiraMovimentacaoDetalhe(
        tituloConclusao: 'Compra concluída',
        subtitulo: 'Token (demonstração)',
        valorReaisExibicao: valorTxt,
        dataHora: dt,
        linhaRodapeOpcional:
            'Quantidade: ${formatQuantidadeTokensBr(0)} tokens',
      );
    }
    if (caps.contains('DIVIDENDO')) {
      return CarteiraMovimentacaoDetalhe(
        tituloConclusao: 'Dividendos creditados',
        subtitulo: detalheCaps,
        valorReaisExibicao: valorTxt,
        dataHora: dt,
        linhaRodapeOpcional: 'Rendimento (demonstração)',
      );
    }
    if (caps.contains('TAXA')) {
      return CarteiraMovimentacaoDetalhe(
        tituloConclusao: 'Pagamento concluído',
        subtitulo: detalheCaps,
        valorReaisExibicao: valorTxt,
        dataHora: dt,
        linhaRodapeOpcional: 'Tarifa (demonstração)',
      );
    }
    if (entrada) {
      return CarteiraMovimentacaoDetalhe(
        tituloConclusao: 'Entrada concluída',
        subtitulo: detalheCaps,
        valorReaisExibicao: valorTxt,
        dataHora: dt,
        linhaRodapeOpcional: 'Movimentação (demonstração)',
      );
    }
    return CarteiraMovimentacaoDetalhe(
      tituloConclusao: 'Saída concluída',
      subtitulo: detalheCaps,
      valorReaisExibicao: valorTxt,
      dataHora: dt,
      linhaRodapeOpcional: 'Movimentação (demonstração)',
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
