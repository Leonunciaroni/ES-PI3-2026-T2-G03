// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Helpers de matching — execução directa e motor seguro (sem derrubar callables).

import {
  getFirestore,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

import {runMatchEngine} from "../matchEngine.js";
import {StatusOrdem, type OrdemMatchCandidate} from "../models/ordem.js";
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

/** Converte documento de ordem em candidato para [executeP2pMatch]. */
export function orderDocToMatchCandidate(
  doc: DocumentSnapshot
): OrdemMatchCandidate | null {
  if (!doc.exists) {
    return null;
  }
  const d = doc.data() ?? {};
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

/**
 * Dispara o motor de matching sem propagar erro (ex.: índice Firestore em falta).
 * A ordem já foi gravada — o match pode ser tentado depois.
 */
export async function tryRunMatchEngine(startupId: string): Promise<void> {
  try {
    await runMatchEngine(startupId);
  } catch (err) {
    logger.error("tryRunMatchEngine falhou", {startupId, err});
  }
}

/**
 * Executa match directo entre uma venda e a compra recém-criada.
 * Não depende de queries compostas do motor geral.
 */
export async function matchBuyWithSellOrder(
  startupId: string,
  sellOrderId: string,
  buyOrderId: string
): Promise<{matched: boolean; reason?: string}> {
  const db = getFirestore();
  const orderRoot = db.collection(ORDERS_COLLECTION).doc(startupId);

  const sellSnap = await orderRoot.collection(ORDER_SUBCOL_SELL).doc(sellOrderId).get();
  const buySnap = await orderRoot.collection(ORDER_SUBCOL_BUY).doc(buyOrderId).get();

  const sell = orderDocToMatchCandidate(sellSnap);
  const buy = orderDocToMatchCandidate(buySnap);
  if (!sell || !buy) {
    return {matched: false, reason: "ordem_inexistente"};
  }

  const result = await executeP2pMatch(startupId, sell, buy);
  if (result.matched) {
    return {matched: true};
  }
  return {matched: false, reason: result.reason};
}

/** Mensagem amigável quando o match directo falha. */
export function userMessageForMatchFailure(reason?: string): string {
  switch (reason) {
  case "self_trade_blocked":
    return "Você não pode comprar a sua própria oferta.";
  case "price_no_cross":
    return "O preço da oferta mudou. Tente novamente.";
  case "ordem_inexistente":
    return "A oferta não está mais disponível.";
  default:
    return "Não foi possível concluir a compra desta oferta. "
        + "Verifique saldo e se a oferta ainda está aberta.";
  }
}

/** Valida oferta de venda alvo antes de criar ordem de compra. */
export async function readOpenSellOrderForBuy(
  startupId: string,
  sellOrderId: string,
  buyerUid: string,
  quantity: number
): Promise<{pricePerToken: number; sellerUid: string}> {
  const db = getFirestore();
  const sellSnap = await db
    .collection(ORDERS_COLLECTION)
    .doc(startupId)
    .collection(ORDER_SUBCOL_SELL)
    .doc(sellOrderId)
    .get();

  if (!sellSnap.exists) {
    throw new Error("not_found");
  }

  const data = sellSnap.data() ?? {};
  if (data[ORDER_FIELD_STATUS] !== StatusOrdem.Aberta) {
    throw new Error("not_open");
  }

  const sellerUid = String(data[ORDER_FIELD_UID] ?? "");
  if (sellerUid === buyerUid) {
    throw new Error("self_trade");
  }

  const sellQty = Number(data[ORDER_FIELD_QUANTITY]);
  if (!Number.isInteger(sellQty) || sellQty <= 0 || quantity > sellQty) {
    throw new Error("qty_exceeds");
  }

  const pricePerToken = Number(data[ORDER_FIELD_PRICE]);
  if (!Number.isFinite(pricePerToken) || pricePerToken <= 0) {
    throw new Error("invalid_price");
  }

  return {pricePerToken, sellerUid};
}
