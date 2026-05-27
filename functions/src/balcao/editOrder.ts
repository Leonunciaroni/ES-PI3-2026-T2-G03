// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Callable para editar ordem aberta (quantidade e preço) e ajustar escrow.

import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

import {StatusOrdem, TipoOrdem} from "./models/ordem.js";
import {tryRunMatchEngine} from "./shared/matchHelpers.js";
import {
  ORDER_FIELD_PRICE,
  ORDER_FIELD_QUANTITY,
  ORDER_FIELD_SORT_KEY,
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
import {
  orderBuyLockBrl,
  readAvailableBrl,
  readAvailableTokens,
  readBrlLocked,
  readTokensLocked,
} from "./shared/escrowMath.js";
import {
  assertOrderTotalWithinLimits,
  assertPositiveIntegerQuantity,
  assertPositivePrice,
  assertStartupId,
} from "./shared/orderValidation.js";
import {syncOpenOrderIndexFromRef} from "./shared/userOrderIndex.js";

/**
 * Edita quantidade e preço de uma ordem aberta do usuário.
 *
 * 1. Valida dono e status `open`
 * 2. Libera escrow antigo e reserva o novo valor
 * 3. Atualiza o documento da ordem
 * 4. Dispara match engine
 */
export const editOrder = onCall({region: REGION}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Precisa iniciar sessão.");
  }
  const uid = request.auth.uid;

  const startupId = assertStartupId(request.data?.startupId);
  const orderId =
    typeof request.data?.orderId === "string" ? request.data.orderId.trim() : "";
  const tipoRaw =
    typeof request.data?.tipo === "string" ? request.data.tipo.trim().toLowerCase() : "";
  const quantity = assertPositiveIntegerQuantity(request.data?.quantity);
  const pricePerToken = assertPositivePrice(request.data?.pricePerToken);
  const newTotal = orderBuyLockBrl(quantity, pricePerToken);
  assertOrderTotalWithinLimits(newTotal);

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
        "Só o dono da ordem pode editá-la."
      );
    }

    if (data[ORDER_FIELD_STATUS] !== StatusOrdem.Aberta) {
      throw new HttpsError(
        "failed-precondition",
        "Só é possível editar ordens abertas."
      );
    }

    const oldQty = Number(data[ORDER_FIELD_QUANTITY]);
    const oldPrice = Number(data[ORDER_FIELD_PRICE]);
    if (!Number.isInteger(oldQty) || oldQty <= 0 || !Number.isFinite(oldPrice)) {
      throw new HttpsError("failed-precondition", "Ordem com dados inválidos.");
    }

    const oldTotal = orderBuyLockBrl(oldQty, oldPrice);

    if (subcol === ORDER_SUBCOL_SELL) {
      const positionRef = db
        .collection(WALLET_ROOT)
        .doc(uid)
        .collection("positions")
        .doc(startupId);
      const posSnap = await trx.get(positionRef);
      const posData = posSnap.data() ?? {};

      // Saldo livre + o que esta ordem já reserva = limite para a nova quantidade.
      const disponivelComOrdemAtual =
        readAvailableTokens(posData) + oldQty;
      if (disponivelComOrdemAtual + 1e-9 < quantity) {
        throw new HttpsError(
          "failed-precondition",
          "Você não possui tokens suficientes para esta venda"
        );
      }

      const locked = readTokensLocked(posData);
      trx.set(
        positionRef,
        {
          [POSITION_FIELD_TOKENS_LOCKED]: Math.max(0, locked - oldQty + quantity),
        },
        {merge: true}
      );

      trx.update(orderRef, {
        [ORDER_FIELD_QUANTITY]: quantity,
        [ORDER_FIELD_PRICE]: pricePerToken,
        [ORDER_FIELD_SORT_KEY]: pricePerToken,
      });
    } else {
      const walletRef = db.collection(WALLET_ROOT).doc(uid);
      const walletSnap = await trx.get(walletRef);
      const walletData = walletSnap.data() ?? {};

      // BRL livre + o total já bloqueado por esta ordem.
      const disponivelComOrdemAtual = readAvailableBrl(walletData) + oldTotal;
      if (disponivelComOrdemAtual + 1e-9 < newTotal) {
        throw new HttpsError(
          "failed-precondition",
          "Saldo insuficiente para esta ordem de compra"
        );
      }

      const locked = readBrlLocked(walletData);
      trx.set(
        walletRef,
        {
          [WALLET_FIELD_BRL_LOCKED]: Math.max(0, locked - oldTotal + newTotal),
        },
        {merge: true}
      );

      trx.update(orderRef, {
        [ORDER_FIELD_QUANTITY]: quantity,
        [ORDER_FIELD_PRICE]: pricePerToken,
        [ORDER_FIELD_SORT_KEY]: -pricePerToken,
      });
    }
  });

  logger.info("editOrder", {uid, startupId, orderId, tipo: tipoRaw, quantity, pricePerToken});

  const tipoSide =
    subcol === ORDER_SUBCOL_SELL ? TipoOrdem.Venda : TipoOrdem.Compra;
  await syncOpenOrderIndexFromRef(orderRef, tipoSide);

  await tryRunMatchEngine(startupId);

  return {ok: true};
});
