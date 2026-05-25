// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Cálculos centralizados de **saldo BRL** simulado e **patrimônio**, usados na
// [CarteiraScreen] e na [DashboardScreen]. Todas as fómulas repetem os mesmos
// `amountBrl` e `op` gravados pela Cloud Function `simulateWallet`.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Como cada linha do extrato altera o saldo disponível (reais positivos aumentam ou diminuem conforme operações).
double carteiraDeltaBrlLedgerLinha(Map<String, dynamic> m) {
  final op = m['op'] as String?;
  final amt = (m['amountBrl'] as num?)?.toDouble() ?? 0.0;
  switch (op) {
    case 'credit_pix_simulated':
      return amt;
    case 'withdraw_pix_simulated':
      return -amt;
    case 'trade_buy':
      return -amt;
    case 'trade_sell':
      return amt;
    default:
      return 0.0;
  }
}

/// Reverte, a partir de [brlNow], todas as operações em `[rangeStartInclusive, rangeEndInclusive]`
/// percorrendo o ledger ordenado por **createdAt descendente**.
double carteiraBrlAntesDoIntervalo({
  required double brlNow,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docsNewestFirst,
  required DateTime rangeStartInclusive,
  required DateTime rangeEndInclusive,
}) {
  var b = brlNow;
  for (final d in docsNewestFirst) {
    final m = d.data();
    final ts = m['createdAt'];
    if (ts is! Timestamp) continue;
    final t = ts.toDate();
    if (t.isBefore(rangeStartInclusive) || t.isAfter(rangeEndInclusive)) {
      continue;
    }
    b -= carteiraDeltaBrlLedgerLinha(m);
  }
  return b;
}

/// Valor destacado no card roxo: caixa disponível mais valor de mercado das posições abertas.
double carteiraPatrimonioTotal({
  required double brlDisponivel,
  required double valorMercadoPosicoes,
}) =>
    brlDisponivel + valorMercadoPosicoes;

/// Texto tipo "+ 3,2% este mês" baseado apenas no **saldo BRL** antes do primeiro dia útil atual e hoje — espelho do chip da carteira.
String carteiraVariacaoSaldoMesLabel({
  required double brlNow,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docsNewestFirst,
  required DateTime now,
}) {
  final inicioMes = DateTime(now.year, now.month, 1);
  final brlIni = carteiraBrlAntesDoIntervalo(
    brlNow: brlNow,
    docsNewestFirst: docsNewestFirst,
    rangeStartInclusive: inicioMes,
    rangeEndInclusive: now,
  );
  if (brlIni.abs() < 1.0) {
    if (brlNow.abs() >= 1.0) {
      return '+ 100,0% este mês';
    }
    return '+ 0,0% este mês';
  }
  final pct = (brlNow - brlIni) / brlIni * 100;
  final s = pct.toStringAsFixed(1).replaceAll('.', ',');
  final sign = pct >= 0 ? '+ ' : '';
  return '$sign$s% este mês';
}

/// Saldo disponível reconstruído **como ao fecho** do instante [instanteInclusive]:
/// todas as operações com `createdAt` **posterior** a esse marco são desfeitas
/// (lista [docsNewestFirst] igual à query ordenada descendente à Firestore).
double saldoBrlAoFechoInstanteInclusive({
  required double brlNow,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docsNewestFirst,
  required DateTime instanteInclusive,
}) {
  var b = brlNow;
  for (final d in docsNewestFirst) {
    final m = d.data();
    final ts = m['createdAt'];
    if (ts is! Timestamp) continue;
    final t = ts.toDate();
    if (!t.isAfter(instanteInclusive)) {
      break;
    }
    b -= carteiraDeltaBrlLedgerLinha(m);
  }
  return b;
}
