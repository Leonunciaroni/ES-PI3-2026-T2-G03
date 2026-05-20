// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Callable para publicar ordem de compra no Order Book P2P.

import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

import {StatusOrdem} from "./models/ordem.js";
import {
  ORDER_FIELD_CREATED_AT,
  ORDER_FIELD_DISPLAY_NAME,
  ORDER_FIELD_PRICE,
  ORDER_FIELD_QUANTITY,
  ORDER_FIELD_SORT_KEY,
  ORDER_FIELD_STARTUP_ID,
  ORDER_FIELD_STARTUP_NAME,
  ORDER_FIELD_STATUS,
  ORDER_FIELD_TOKEN_SIGLA,
  ORDER_FIELD_UID,
  ORDER_SUBCOL_BUY,
  ORDERS_COLLECTION,
  REGION,
  WALLET_FIELD_BRL_LOCKED,
  WALLET_ROOT,
} from "./shared/constants.js";
import {
  orderBuyLockBrl,
  readAvailableBrl,
  readBrlLocked,
} from "./shared/escrowMath.js";
import {
  assertOrderTotalWithinLimits,
  assertPositiveIntegerQuantity,
  assertPositivePrice,
  assertStartupId,
} from "./shared/orderValidation.js";
import {resolveDisplayName} from "./shared/resolveDisplayName.js";
import {readStartupOrderMeta} from "./shared/startupOrderMeta.js";
import {runMatchEngine} from "./matchEngine.js";

/**
 * Publica ordem de compra com escrow de BRL.
 *
 * 1. Valida auth e campos
 * 2. Calcula total e verifica saldo disponível (balance − locked)
 * 3. Reserva BRL em `brlLockedInOrders`
 * 4. Cria documento em `orders/{startupId}/buy/{autoId}`
 * 5. Dispara match engine
 */
export const addBuyOrder = onCall({region: REGION}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Precisa iniciar sessão.");
  }
  const uid = request.auth.uid;

  const startupId = assertStartupId(request.data?.startupId);
  const quantity = assertPositiveIntegerQuantity(request.data?.quantity);
  const pricePerToken = assertPositivePrice(request.data?.pricePerToken);
  const totalValue = orderBuyLockBrl(quantity, pricePerToken);
  assertOrderTotalWithinLimits(totalValue);

  const db = getFirestore();
  const meta = await readStartupOrderMeta(startupId);
  const displayName = await resolveDisplayName(uid, request.auth.token.email as string | undefined);

  const walletRef = db.collection(WALLET_ROOT).doc(uid);
  const orderRootRef = db.collection(ORDERS_COLLECTION).doc(startupId);
  const orderRef = orderRootRef.collection(ORDER_SUBCOL_BUY).doc();

  // sortKey negativo: maior preço de compra fica no topo (ordenação decrescente).
  const sortKey = -pricePerToken;

  await db.runTransaction(async (trx) => {
    const walletSnap = await trx.get(walletRef);
    const walletData = walletSnap.data() ?? {};
    const disponivel = readAvailableBrl(walletData);

    if (disponivel + 1e-9 < totalValue) {
      throw new HttpsError(
        "failed-precondition",
        "Saldo insuficiente para criar esta ordem de compra"
      );
    }

    const lockedPrev = readBrlLocked(walletData);
    trx.set(
      walletRef,
      {
        [WALLET_FIELD_BRL_LOCKED]: lockedPrev + totalValue,
      },
      {merge: true}
    );

    trx.set(orderRootRef, {startupId}, {merge: true});

    trx.set(orderRef, {
      [ORDER_FIELD_UID]: uid,
      [ORDER_FIELD_DISPLAY_NAME]: displayName,
      [ORDER_FIELD_STARTUP_ID]: startupId,
      [ORDER_FIELD_STARTUP_NAME]: meta.startupName,
      [ORDER_FIELD_TOKEN_SIGLA]: meta.tokenSigla,
      [ORDER_FIELD_QUANTITY]: quantity,
      [ORDER_FIELD_PRICE]: pricePerToken,
      [ORDER_FIELD_SORT_KEY]: sortKey,
      [ORDER_FIELD_STATUS]: StatusOrdem.Aberta,
      [ORDER_FIELD_CREATED_AT]: FieldValue.serverTimestamp(),
    });
  });

  logger.info("addBuyOrder", {uid, startupId, quantity, pricePerToken, totalValue});

  await runMatchEngine(startupId);

  return {ok: true, orderId: orderRef.id};
});
