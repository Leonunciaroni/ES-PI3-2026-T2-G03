// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Liberta escrow BRL de ordem de compra cancelada internamente.

import {getFirestore} from "firebase-admin/firestore";

import {StatusOrdem} from "../models/ordem.js";
import {
  ORDER_FIELD_PRICE,
  ORDER_FIELD_QUANTITY,
  ORDER_FIELD_STATUS,
  ORDER_SUBCOL_BUY,
  ORDERS_COLLECTION,
  WALLET_FIELD_BRL_LOCKED,
  WALLET_ROOT,
} from "./constants.js";
import {orderBuyLockBrl, readBrlLocked} from "./escrowMath.js";

/**
 * Cancela ordem de compra aberta e devolve BRL bloqueado.
 * Usado quando o match directo com uma oferta falha após criar a compra.
 */
export async function rollbackOpenBuyOrder(
  uid: string,
  startupId: string,
  buyOrderId: string
): Promise<void> {
  const db = getFirestore();
  const orderRef = db
    .collection(ORDERS_COLLECTION)
    .doc(startupId)
    .collection(ORDER_SUBCOL_BUY)
    .doc(buyOrderId);
  const walletRef = db.collection(WALLET_ROOT).doc(uid);

  await db.runTransaction(async (trx) => {
    const orderSnap = await trx.get(orderRef);
    if (!orderSnap.exists) {
      return;
    }

    const data = orderSnap.data() ?? {};
    if (data[ORDER_FIELD_STATUS] !== StatusOrdem.Aberta) {
      return;
    }

    const quantity = Number(data[ORDER_FIELD_QUANTITY]);
    const pricePerToken = Number(data[ORDER_FIELD_PRICE]);
    const releaseBrl = orderBuyLockBrl(quantity, pricePerToken);

    const walletSnap = await trx.get(walletRef);
    const locked = readBrlLocked(walletSnap.data());

    trx.update(orderRef, {[ORDER_FIELD_STATUS]: StatusOrdem.Cancelada});
    trx.set(
      walletRef,
      {[WALLET_FIELD_BRL_LOCKED]: Math.max(0, locked - releaseBrl)},
      {merge: true}
    );
  });
}
