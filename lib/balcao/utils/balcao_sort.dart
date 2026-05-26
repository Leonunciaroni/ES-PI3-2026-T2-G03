// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Bubble sort para ordenar ordens do Order Book após receber do Firestore.

import '../models/ordem_model.dart';

/// Ordena ordens do livro para exibição no [AnimatedList].
///
/// Regras (o [sortKey] vem calculado pelo backend):
/// - Venda: `sortKey = +pricePerToken` → menor preço no topo (ordem decrescente de sortKey).
/// - Compra: `sortKey = -pricePerToken` → maior preço no topo.
/// - Empate em [sortKey]: [createdAt] ascendente (quem chegou primeiro fica na frente).
List<OrdemModel> bubbleSortOrdens(List<OrdemModel> ordens) {
  // Trabalhamos sobre cópia para não mutar a lista original do stream.
  final lista = List<OrdemModel>.from(ordens);
  final n = lista.length;
  if (n < 2) return lista;

  // Bubble sort clássico: compara pares adjacentes e troca quando fora de ordem.
  for (var pass = 0; pass < n - 1; pass++) {
    var houveTroca = false;

    for (var i = 0; i < n - 1 - pass; i++) {
      final a = lista[i];
      final b = lista[i + 1];

      // Ordem decrescente por sortKey (maior sortKey primeiro).
      final aAntesDeB = _deveVirAntes(a, b);

      if (!aAntesDeB) {
        // Troca: o elemento com prioridade menor desce na lista.
        lista[i] = b;
        lista[i + 1] = a;
        houveTroca = true;
      }
    }

    // Otimização: se nenhuma troca ocorreu, a lista já está ordenada.
    if (!houveTroca) break;
  }

  return lista;
}

/// Retorna `true` se [a] deve aparecer antes de [b] na lista ordenada.
bool _deveVirAntes(OrdemModel a, OrdemModel b) {
  if (a.sortKey != b.sortKey) {
    return a.sortKey > b.sortKey;
  }

  // Empate: createdAt mais antigo primeiro (ascendente).
  final ta = a.createdAt;
  final tb = b.createdAt;
  if (ta == null && tb == null) return false;
  if (ta == null) return false;
  if (tb == null) return true;
  return ta.isBefore(tb);
}
