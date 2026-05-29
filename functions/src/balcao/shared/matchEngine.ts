// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Motor de matching — cruza ordens abertas de venda e compra.

import {type QueryDocumentSnapshot} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

import {
  ORDER_FIELD_PRICE,
  ORDER_FIELD_QUANTITY,
  ORDER_FIELD_STATUS,
  ORDER_FIELD_UID,
  ORDER_SUBCOL_BUY,
  ORDER_SUBCOL_SELL,
  ORDERS_COLLECTION,
} from "./constants.js";
import {executeP2pMatch} from "./executeP2pMatch.js";
import {db} from "./firebase.js";
import {StatusOrdem, type OrdemMatchCandidate} from "../types/index.js";

const MAX_MATCH_ITERATIONS = 50;

/**
 * Tenta executar matches até não haver mais pares compatíveis.
 *
 * 1. Busca vendas abertas (menor preço primeiro)
 * 2. Busca compras abertas (maior preço primeiro)
 * 3. Encontra par com preços cruzados e UIDs distintos (sem self-trade)
 * 4. Executa transação P2P
 * 5. Repete
 */
export async function runMatchEngine(startupId: string): Promise<void> {
  const orderRoot = db.collection(ORDERS_COLLECTION).doc(startupId);

  for (let i = 0; i < MAX_MATCH_ITERATIONS; i++) {
    // 1. Ordens de venda abertas — pricePerToken ASC, createdAt ASC
    const sellSnap = await orderRoot
      .collection(ORDER_SUBCOL_SELL)
      .where(ORDER_FIELD_STATUS, "==", StatusOrdem.Aberta)
      .orderBy(ORDER_FIELD_PRICE, "asc")
      .orderBy("createdAt", "asc")
      .limit(30)
      .get();

    // 2. Ordens de compra abertas — pricePerToken DESC, createdAt ASC
    const buySnap = await orderRoot
      .collection(ORDER_SUBCOL_BUY)
      .where(ORDER_FIELD_STATUS, "==", StatusOrdem.Aberta)
      .orderBy(ORDER_FIELD_PRICE, "desc")
      .orderBy("createdAt", "asc")
      .limit(30)
      .get();

    if (sellSnap.empty || buySnap.empty) {
      return;
    }

    const sells = sellSnap.docs.map(mapSellCandidate);
    const buys = buySnap.docs.map(mapBuyCandidate);

    // 3–4. Tenta pares compatíveis em ordem; se um falhar (escrow/saldo), tenta o próximo.
    let matchedThisRound = false;
    outer:
    for (const sell of sells) {
      for (const buy of buys) {
        if (sell.uid === buy.uid) {
          continue;
        }
        if (sell.pricePerToken > buy.pricePerToken + 1e-12) {
          continue;
        }

        const result = await executeP2pMatch(startupId, sell, buy);
        if (!result.matched) {
          logger.info("runMatchEngine: par ignorado", {
            startupId,
            reason: result.reason,
            sellId: sell.id,
            buyId: buy.id,
          });
          continue;
        }

        logger.info("runMatchEngine: match executado", {
          startupId,
          iteration: i + 1,
          sellId: sell.id,
          buyId: buy.id,
        });
        matchedThisRound = true;
        break outer;
      }
    }

    if (!matchedThisRound) {
      return;
    }
  }

  logger.warn("runMatchEngine: limite de iterações atingido", {startupId});
}

function mapSellCandidate(
  doc: QueryDocumentSnapshot
): OrdemMatchCandidate {
  const d = doc.data();
  return {
    id: doc.id,
    ref: doc.ref,
    uid: String(d[ORDER_FIELD_UID] ?? ""),
    quantity: Number(d[ORDER_FIELD_QUANTITY]),
    pricePerToken: Number(d[ORDER_FIELD_PRICE]),
    createdAt: d.createdAt,
    startupName: String(d.startupName ?? ""),
    tokenSigla: String(d.tokenSigla ?? ""),
  };
}

function mapBuyCandidate(
  doc: QueryDocumentSnapshot
): OrdemMatchCandidate {
  return mapSellCandidate(doc);
}
