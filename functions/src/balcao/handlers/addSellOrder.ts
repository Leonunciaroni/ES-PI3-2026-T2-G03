// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Callable para publicar ordem de venda no Order Book P2P.

import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

import {readStartupOrderMeta} from "../repositories/startupOrderMeta.js";
import {syncOpenOrderIndexFromRef} from "../repositories/userOrderIndex.js";
import {requireAuthenticatedUser} from "../shared/auth.js";
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
  ORDER_SUBCOL_SELL,
  ORDERS_COLLECTION,
  POSITION_FIELD_TOKENS_LOCKED,
  REGION,
  WALLET_ROOT,
} from "../shared/constants.js";
import {readAvailableTokens, readTokensLocked} from "../shared/escrowMath.js";
import {tryRunMatchEngine} from "../shared/matchHelpers.js";
import {
  assertOrderTotalWithinLimits,
  assertPositiveIntegerQuantity,
  assertPositivePrice,
  assertStartupId,
} from "../shared/orderValidation.js";
import {resolveDisplayName} from "../shared/resolveDisplayName.js";
import {db} from "../shared/firebase.js";
import {StatusOrdem, TipoOrdem} from "../types/index.js";

/**
 * Publica ordem de venda com escrow de tokens.
 *
 * 1. Valida auth e campos
 * 2. Verifica tokens disponíveis (held − locked)
 * 3. Reserva tokens em `tokensLockedInOrders`
 * 4. Cria documento em `orders/{startupId}/sell/{autoId}`
 * 5. Dispara match engine
 */
export const addSellOrder = onCall({region: REGION}, async (request) => {
  const user = requireAuthenticatedUser(request);
  const uid = user.uid;

  const startupId = assertStartupId(request.data?.startupId);
  const quantity = assertPositiveIntegerQuantity(request.data?.quantity);
  const pricePerToken = assertPositivePrice(request.data?.pricePerToken);
  const totalValue = quantity * pricePerToken;
  assertOrderTotalWithinLimits(totalValue);

  const meta = await readStartupOrderMeta(startupId);
  const displayName = await resolveDisplayName(uid, user.email);

  const walletRef = db.collection(WALLET_ROOT).doc(uid);
  const positionRef = walletRef.collection("positions").doc(startupId);
  const orderRootRef = db.collection(ORDERS_COLLECTION).doc(startupId);
  const orderRef = orderRootRef.collection(ORDER_SUBCOL_SELL).doc();

  // sortKey positivo: menor preço fica no topo após ordenação decrescente no app.
  const sortKey = pricePerToken;

  await db.runTransaction(async (trx) => {
    const posSnap = await trx.get(positionRef);
    if (!posSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Você não possui tokens suficientes para esta venda"
      );
    }

    const posData = posSnap.data() ?? {};
    const disponivel = readAvailableTokens(posData);
    if (disponivel + 1e-9 < quantity) {
      throw new HttpsError(
        "failed-precondition",
        "Você não possui tokens suficientes para esta venda"
      );
    }

    const lockedPrev = readTokensLocked(posData);
    trx.set(
      positionRef,
      {
        [POSITION_FIELD_TOKENS_LOCKED]: lockedPrev + quantity,
        updatedAt: FieldValue.serverTimestamp(),
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

  logger.info("addSellOrder", {uid, startupId, quantity, pricePerToken});

  await syncOpenOrderIndexFromRef(orderRef, TipoOrdem.Venda);

  await tryRunMatchEngine(startupId);

  return {ok: true, orderId: orderRef.id};
});
