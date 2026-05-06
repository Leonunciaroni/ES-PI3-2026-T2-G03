// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Rendimento e mini-série da posição **por startup**, alinhados ao modelo do ledger
// nas Cloud Functions (`tokenPerformanceMath`): tokens acumulados até cada instante ×
// último preço negociado até esse instante (senão cotação atual do catálogo).

import 'package:cloud_firestore/cloud_firestore.dart';

/// Linha normalizada do ledger para compras/vendas de tokens.
class CarteiraLedgerTradeRow {
  const CarteiraLedgerTradeRow({
    required this.at,
    required this.isBuy,
    required this.startupId,
    required this.tokensQuantity,
    required this.tokenPriceBrl,
  });

  final DateTime at;
  final bool isBuy;
  final String startupId;
  final double tokensQuantity;
  final double tokenPriceBrl;
}

/// Ordem ascendente por data (replay temporal).
List<CarteiraLedgerTradeRow> carteiraParseLedgerTradesAscending(
  QuerySnapshot<Map<String, dynamic>> snap,
) {
  final rows = <CarteiraLedgerTradeRow>[];
  for (final doc in snap.docs) {
    final m = doc.data();
    final op = m['op'] as String?;
    if (op != 'trade_buy' && op != 'trade_sell') continue;
    final ts = m['createdAt'];
    DateTime? at;
    if (ts is Timestamp) {
      at = ts.toDate();
    }
    if (at == null) continue;

    final sid = (m['startupId'] as String?)?.trim() ?? '';
    if (sid.isEmpty) continue;

    final tokensQuantity = (m['tokensQuantity'] as num?)?.toDouble() ?? 0.0;
    final tokenPriceBrl = (m['tokenPriceBrl'] as num?)?.toDouble() ?? 0.0;
    if (!(tokensQuantity > 0) || !(tokenPriceBrl > 0)) continue;

    rows.add(
      CarteiraLedgerTradeRow(
        at: at,
        isBuy: op == 'trade_buy',
        startupId: sid,
        tokensQuantity: tokensQuantity,
        tokenPriceBrl: tokenPriceBrl,
      ),
    );
  }
  rows.sort((a, b) => a.at.compareTo(b.at));
  return rows;
}

double carteiraTokensHeldForStartupAt(
  List<CarteiraLedgerTradeRow> tradesAsc,
  String startupId,
  DateTime deadline,
) {
  var t = 0.0;
  for (final r in tradesAsc) {
    if (r.at.isAfter(deadline)) {
      break;
    }
    if (r.startupId != startupId) {
      continue;
    }
    if (r.isBuy) {
      t += r.tokensQuantity;
    } else {
      t -= r.tokensQuantity;
    }
  }
  return t;
}

double carteiraLastTradePriceBefore(
  List<CarteiraLedgerTradeRow> tradesAsc,
  String startupId,
  DateTime deadline,
  double fallbackPriceBrl,
) {
  double? last;
  for (final r in tradesAsc) {
    if (r.at.isAfter(deadline)) {
      break;
    }
    if (r.startupId != startupId) {
      continue;
    }
    if (r.tokenPriceBrl > 0) {
      last = r.tokenPriceBrl;
    }
  }
  if (last != null) {
    return last;
  }
  return (fallbackPriceBrl > 0) ? fallbackPriceBrl : 0.0;
}

double carteiraSingleStartupMarketValueBrl(
  List<CarteiraLedgerTradeRow> tradesAsc,
  String startupId,
  DateTime deadline,
  double fallbackPriceBrl,
  double tokensHeldIfLedgerEmpty,
) {
  final tok = tradesAsc.isEmpty
      ? tokensHeldIfLedgerEmpty
      : carteiraTokensHeldForStartupAt(tradesAsc, startupId, deadline);
  final px = tradesAsc.isEmpty
      ? fallbackPriceBrl
      : carteiraLastTradePriceBefore(
          tradesAsc,
          startupId,
          deadline,
          fallbackPriceBrl,
        );
  return tok * px;
}

/// Valores em BRL nos instantes [sampleTimes] (valor da posição = tokens × preço).
List<double> carteiraSingleStartupSparklineValues(
  List<CarteiraLedgerTradeRow> tradesAsc, {
  required String startupId,
  required double fallbackPriceBrl,
  required List<DateTime> sampleTimes,
  required double tokensHeldNowFromDoc,
}) {
  return sampleTimes
      .map(
        (t) => carteiraSingleStartupMarketValueBrl(
          tradesAsc,
          startupId,
          t,
          fallbackPriceBrl,
          tokensHeldNowFromDoc,
        ),
      )
      .toList();
}

/// Tom para cor na UI (roxo = neutro ou sem dado; verde/vermelho = rendimento).
enum CarteiraInvestidoYieldTone {
  indefinido,
  neutro,
  positivo,
  negativo,
}

/// Percentual bruto do rendimento ou `null` se não for exibível (`N/D`).
double? carteiraYieldPercentRaw({
  required double costBasisBrl,
  required double tokensHeld,
  required double tokenPriceBrl,
}) {
  if (!(costBasisBrl > 1e-9)) {
    return null;
  }
  if (!(tokenPriceBrl > 0) || !tokenPriceBrl.isFinite) {
    return null;
  }
  if (!tokensHeld.isFinite || tokensHeld < -1e-9) {
    return null;
  }
  final mv = tokensHeld * tokenPriceBrl;
  final pct = 100.0 * (mv - costBasisBrl) / costBasisBrl;
  if (!pct.isFinite) {
    return null;
  }
  return pct;
}

/// Rendimento % da posição: \((V_mercado - custo) / custo\) com \(V_mercado = tokens × preço atual\).
String carteiraYieldPercentLabel({
  required double costBasisBrl,
  required double tokensHeld,
  required double tokenPriceBrl,
}) {
  final pct = carteiraYieldPercentRaw(
    costBasisBrl: costBasisBrl,
    tokensHeld: tokensHeld,
    tokenPriceBrl: tokenPriceBrl,
  );
  if (pct == null) {
    return 'N/D';
  }
  final abs = pct.abs().toStringAsFixed(1).replaceAll('.', ',');
  if (pct > 0.05) {
    return '+$abs%';
  }
  if (pct < -0.05) {
    return '-$abs%';
  }
  return '0,0%';
}

CarteiraInvestidoYieldTone carteiraYieldTone({
  required double costBasisBrl,
  required double tokensHeld,
  required double tokenPriceBrl,
}) {
  final pct = carteiraYieldPercentRaw(
    costBasisBrl: costBasisBrl,
    tokensHeld: tokensHeld,
    tokenPriceBrl: tokenPriceBrl,
  );
  if (pct == null) {
    return CarteiraInvestidoYieldTone.indefinido;
  }
  if (pct.abs() <= 0.05) {
    return CarteiraInvestidoYieldTone.neutro;
  }
  if (pct > 0.05) {
    return CarteiraInvestidoYieldTone.positivo;
  }
  return CarteiraInvestidoYieldTone.negativo;
}

/// Convidadas / texto já formatado (ex.: `+18,5%`, `N/D`) para escolher a cor sem números.
CarteiraInvestidoYieldTone carteiraYieldToneFromFormattedLabel(String label) {
  final s = label.trim();
  if (s.isEmpty || s.contains('N/D') || s.contains('•')) {
    return CarteiraInvestidoYieldTone.indefinido;
  }
  if (s.startsWith('+')) {
    return CarteiraInvestidoYieldTone.positivo;
  }
  if (s.startsWith('-')) {
    return CarteiraInvestidoYieldTone.negativo;
  }
  if (s.startsWith('0') || s == '0,0%') {
    return CarteiraInvestidoYieldTone.neutro;
  }
  return CarteiraInvestidoYieldTone.indefinido;
}
