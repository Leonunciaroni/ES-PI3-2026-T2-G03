// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Callable para cancelar ordem aberta e liberar escrow.

import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

import {StatusOrdem, TipoOrdem} from "./models/ordem.js";
import {
  ORDER_FIELD_PRICE,
  ORDER_FIELD_QUANTITY,
  ORDER_FIELD_STATUS,
  ORDER_FIELD_UID,
  ORDER_SUBCOL_BUY,
  ORDER_SUBCOL_SELL,
  ORDERS_COLLECTION,
  POSITION_FIELD_TOKENS_LOCKED,
  REGION,
  WALLET_FIELD_BRL_LOCKED,
  WALLET_ROOT,
} from "./shared/constants.js";
import {orderBuyLockBrl, readBrlLocked, readTokensLocked} from "./shared/escrowMath.js";
import {assertStartupId} from "./shared/orderValidation.js";
import {removeUserOpenOrderIndex} from "./shared/userOrderIndex.js";

/**
 * Cancela ordem aberta do usuário autenticado.
 *
 * 1. Valida dono e status `open`
 * 2. Marca como `cancelled`
 * 3. Libera escrow (BRL ou tokens)
 */
export const cancelOrder = onCall({region: REGION}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Precisa iniciar sessão.");
  }
  const uid = request.auth.uid;

  const startupId = assertStartupId(request.data?.startupId);
  const orderId =
    typeof request.data?.orderId === "string" ? request.data.orderId.trim() : "";
  const tipoRaw =
    typeof request.data?.tipo === "string" ? request.data.tipo.trim().toLowerCase() : "";

  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId obrigatório.");
  }

  let subcol: string;
  if (tipoRaw === TipoOrdem.Compra) {
    subcol = ORDER_SUBCOL_BUY;
  } else if (tipoRaw === TipoOrdem.Venda) {
    subcol = ORDER_SUBCOL_SELL;
  } else {
    throw new HttpsError("invalid-argument", "tipo deve ser buy ou sell.");
  }

  const db = getFirestore();
  const orderRef = db
    .collection(ORDERS_COLLECTION)
    .doc(startupId)
    .collection(subcol)
    .doc(orderId);

  await db.runTransaction(async (trx) => {
    const orderSnap = await trx.get(orderRef);
    if (!orderSnap.exists) {
      throw new HttpsError("not-found", "Ordem não encontrada.");
    }

    const data = orderSnap.data() ?? {};
    const ownerUid = String(data[ORDER_FIELD_UID] ?? "");

    if (ownerUid !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Só o dono da ordem pode cancelá-la."
      );
    }

    if (data[ORDER_FIELD_STATUS] !== StatusOrdem.Aberta) {
      throw new HttpsError(
        "failed-precondition",
        "Só é possível cancelar ordens abertas."
      );
    }

    const quantity = Number(data[ORDER_FIELD_QUANTITY]);
    const pricePerToken = Number(data[ORDER_FIELD_PRICE]);

    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new HttpsError("failed-precondition", "Ordem com quantidade inválida.");
    }

    if (subcol === ORDER_SUBCOL_SELL) {
      const positionRef = db
        .collection(WALLET_ROOT)
        .doc(uid)
        .collection("positions")
        .doc(startupId);
      const posSnap = await trx.get(positionRef);
      const locked = readTokensLocked(posSnap.data());

      trx.update(orderRef, {[ORDER_FIELD_STATUS]: StatusOrdem.Cancelada});
      trx.set(
        positionRef,
        {[POSITION_FIELD_TOKENS_LOCKED]: Math.max(0, locked - quantity)},
        {merge: true}
      );
    } else {
      const walletRef = db.collection(WALLET_ROOT).doc(uid);
      const walletSnap = await trx.get(walletRef);
      const locked = readBrlLocked(walletSnap.data());
      const releaseBrl = orderBuyLockBrl(quantity, pricePerToken);

      trx.update(orderRef, {[ORDER_FIELD_STATUS]: StatusOrdem.Cancelada});
      trx.set(
        walletRef,
        {[WALLET_FIELD_BRL_LOCKED]: Math.max(0, locked - releaseBrl)},
        {merge: true}
      );
    }
  });

  logger.info("cancelOrder", {uid, startupId, orderId, tipo: tipoRaw});

  const tipoSide =
    subcol === ORDER_SUBCOL_SELL ? TipoOrdem.Venda : TipoOrdem.Compra;
  await removeUserOpenOrderIndex(uid, tipoSide, orderId);

  return {ok: true};
});
