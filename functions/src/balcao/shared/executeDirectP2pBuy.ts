// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Compra P2P directa de uma oferta de venda — uma transação atómica.

import {FieldValue} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

import {syncOpenOrderIndexFromRef} from "../repositories/userOrderIndex.js";
import {
  ORDER_FIELD_PRICE,
  ORDER_FIELD_QUANTITY,
  ORDER_FIELD_STATUS,
  ORDER_FIELD_UID,
  ORDER_SUBCOL_SELL,
  ORDERS_COLLECTION,
  POSITION_FIELD_TOKENS_LOCKED,
  STARTUP_FIELD_INVESTOR_UIDS,
  STARTUPS_COLLECTION,
  USER_FIELD_INVESTOR_STARTUP_IDS,
  USERS_COLLECTION,
  WALLET_ROOT,
} from "./constants.js";
import {
  readAvailableBrl,
  readAvailableTokens,
  readBrlBalance,
  readTokensHeld,
  readTokensLocked,
} from "./escrowMath.js";
import {db} from "./firebase.js";
import {
  StatusOrdem,
  TipoOrdem,
  type DirectP2pBuyResult,
} from "../types/index.js";
import {
  computeSellPositionUpdate,
  mergeBuyPosition,
} from "../../wallet/shared/positionTradeMath.js";

/**
 * Compra tokens de uma ordem de venda aberta numa única transação.
 *
 * Não cria ordem de compra intermédia — evita falhas de escrow/match engine.
 */
export async function executeDirectP2pBuy(params: {
  startupId: string;
  sellOrderId: string;
  buyerUid: string;
  quantity: number;
}): Promise<DirectP2pBuyResult> {
  const {startupId, sellOrderId, buyerUid, quantity} = params;

  const sellRef = db
    .collection(ORDERS_COLLECTION)
    .doc(startupId)
    .collection(ORDER_SUBCOL_SELL)
    .doc(sellOrderId);

  const buyerWalletRef = db.collection(WALLET_ROOT).doc(buyerUid);
  const buyerPosRef = buyerWalletRef.collection("positions").doc(startupId);
  const startupRef = db.collection(STARTUPS_COLLECTION).doc(startupId);

  const trade = await db.runTransaction(async (trx) => {
    const sellSnap = await trx.get(sellRef);
    if (!sellSnap.exists) {
      throw new HttpsError("not-found", "Oferta de venda não encontrada.");
    }

    const sellData = sellSnap.data() ?? {};
    if (sellData[ORDER_FIELD_STATUS] !== StatusOrdem.Aberta) {
      throw new HttpsError(
        "failed-precondition",
        "Esta oferta não está mais aberta."
      );
    }

    const sellerUid = String(sellData[ORDER_FIELD_UID] ?? "");
    if (sellerUid === buyerUid) {
      throw new HttpsError(
        "failed-precondition",
        "Você não pode comprar a sua própria oferta."
      );
    }

    const sellQty = Number(sellData[ORDER_FIELD_QUANTITY]);
    const sellPrice = Number(sellData[ORDER_FIELD_PRICE]);
    if (!Number.isInteger(sellQty) || sellQty <= 0 || !Number.isFinite(sellPrice)) {
      throw new HttpsError("failed-precondition", "Oferta com dados inválidos.");
    }
    if (quantity > sellQty) {
      throw new HttpsError(
        "failed-precondition",
        "Quantidade maior que a disponível na oferta."
      );
    }

    const tradeQty = quantity;
    const executionPrice = sellPrice;
    const amountBrl = tradeQty * executionPrice;

    const startupName = String(sellData.startupName ?? "Startup");
    const tokenSigla = String(sellData.tokenSigla ?? "");

    const sellerWalletRef = db.collection(WALLET_ROOT).doc(sellerUid);
    const sellerPosRef = sellerWalletRef.collection("positions").doc(startupId);

    const [buyerWalletSnap, buyerPosSnap, sellerWalletSnap, sellerPosSnap] =
      await Promise.all([
        trx.get(buyerWalletRef),
        trx.get(buyerPosRef),
        trx.get(sellerWalletRef),
        trx.get(sellerPosRef),
      ]);

    const buyerWallet = buyerWalletSnap.data() ?? {};
    const sellerPos = sellerPosSnap.data() ?? {};

    const brlDisponivel = readAvailableBrl(buyerWallet);
    if (brlDisponivel + 1e-9 < amountBrl) {
      throw new HttpsError(
        "failed-precondition",
        "Saldo insuficiente para esta compra"
      );
    }

    const tokensDisponiveisVendedor = readAvailableTokens(sellerPos);
    if (tokensDisponiveisVendedor + 1e-9 < tradeQty) {
      throw new HttpsError(
        "failed-precondition",
        "O vendedor não possui mais tokens suficientes nesta oferta."
      );
    }

    const sellerHeld = readTokensHeld(sellerPos);
    const sellerLocked = readTokensLocked(sellerPos);
    const buyerBalance = readBrlBalance(buyerWallet);

    // --- Comprador: debita BRL disponível e incrementa posição ---
    const buyerPosData = buyerPosSnap.data() ?? {};
    const prevBuyerPos =
      buyerPosSnap.exists &&
      (typeof buyerPosData.tokensHeld === "number" ||
        typeof buyerPosData.costBasisBrl === "number")
        ? {
            tokensHeld:
              typeof buyerPosData.tokensHeld === "number"
                ? buyerPosData.tokensHeld
                : 0,
            costBasisBrl:
              typeof buyerPosData.costBasisBrl === "number"
                ? buyerPosData.costBasisBrl
                : 0,
          }
        : undefined;

    const {tokensHeld: buyerTokens, costBasisBrl: buyerCost} = mergeBuyPosition(
      prevBuyerPos,
      tradeQty,
      amountBrl
    );

    const category =
      typeof buyerPosData.category === "string"
        ? buyerPosData.category
        : typeof sellerPos.category === "string"
          ? sellerPos.category
          : null;

    trx.set(
      buyerWalletRef,
      {brlBalance: buyerBalance - amountBrl},
      {merge: true}
    );

    trx.set(
      buyerPosRef,
      {
        startupId,
        startupName,
        tokenSigla,
        category,
        tokensHeld: buyerTokens,
        costBasisBrl: buyerCost,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    trx.set(
      db.collection(USERS_COLLECTION).doc(buyerUid),
      {[USER_FIELD_INVESTOR_STARTUP_IDS]: FieldValue.arrayUnion(startupId)},
      {merge: true}
    );

    trx.create(buyerWalletRef.collection("ledger").doc(), {
      op: "trade_buy",
      dir: "out",
      headline: tokenSigla
        ? `Compra P2P (${tokenSigla})`
        : "Compra P2P no Order Book",
      amountBrl,
      startupId,
      startupName,
      tokenSigla,
      tokensQuantity: tradeQty,
      tokenPriceBrl: executionPrice,
      createdAt: FieldValue.serverTimestamp(),
    });

    // --- Vendedor: credita BRL, libera escrow e decrementa tokens ---
    const sellUp = computeSellPositionUpdate(
      {
        tokensHeld: sellerHeld,
        costBasisBrl:
          typeof sellerPos.costBasisBrl === "number" ? sellerPos.costBasisBrl : 0,
      },
      tradeQty
    );

    if (!sellUp.ok) {
      throw new HttpsError(
        "failed-precondition",
        "O vendedor não possui tokens suficientes."
      );
    }

    trx.set(
      sellerWalletRef,
      {brlBalance: readBrlBalance(sellerWalletSnap.data() ?? {}) + amountBrl},
      {merge: true}
    );

    if (sellUp.deletePosition) {
      trx.delete(sellerPosRef);
      trx.set(
        db.collection(USERS_COLLECTION).doc(sellerUid),
        {[USER_FIELD_INVESTOR_STARTUP_IDS]: FieldValue.arrayRemove(startupId)},
        {merge: true}
      );
    } else {
      trx.set(
        sellerPosRef,
        {
          startupId,
          startupName,
          tokenSigla,
          category: typeof sellerPos.category === "string" ? sellerPos.category : null,
          tokensHeld: sellUp.tokensHeld,
          costBasisBrl: sellUp.costBasisBrl,
          [POSITION_FIELD_TOKENS_LOCKED]: Math.max(0, sellerLocked - tradeQty),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    }

    trx.create(sellerWalletRef.collection("ledger").doc(), {
      op: "trade_sell",
      dir: "in",
      headline: tokenSigla
        ? `Venda P2P (${tokenSigla})`
        : "Venda P2P no Order Book",
      amountBrl,
      startupId,
      startupName,
      tokenSigla,
      tokensQuantity: tradeQty,
      tokenPriceBrl: executionPrice,
      createdAt: FieldValue.serverTimestamp(),
    });

    if (sellUp.deletePosition) {
      trx.set(
        startupRef,
        {[STARTUP_FIELD_INVESTOR_UIDS]: FieldValue.arrayRemove(sellerUid)},
        {merge: true}
      );
      trx.delete(startupRef.collection("investors").doc(sellerUid));
    }

    trx.set(
      startupRef,
      {[STARTUP_FIELD_INVESTOR_UIDS]: FieldValue.arrayUnion(buyerUid)},
      {merge: true}
    );

    trx.set(
      startupRef.collection("investors").doc(buyerUid),
      {uid: buyerUid, updatedAt: FieldValue.serverTimestamp()},
      {merge: true}
    );

    // --- Atualiza ordem de venda ---
    const sellRemaining = sellQty - tradeQty;
    if (sellRemaining <= 0) {
      trx.update(sellRef, {[ORDER_FIELD_STATUS]: StatusOrdem.Executada});
    } else {
      trx.update(sellRef, {[ORDER_FIELD_QUANTITY]: sellRemaining});
    }

    return {
      quantity: tradeQty,
      amountBrl,
      pricePerToken: executionPrice,
      startupName,
      tokenSigla,
    } satisfies DirectP2pBuyResult;
  });

  await syncOpenOrderIndexFromRef(sellRef, TipoOrdem.Venda);

  logger.info("executeDirectP2pBuy ok", {
    startupId,
    sellOrderId,
    buyerUid,
    quantity: trade.quantity,
    amountBrl: trade.amountBrl,
    pricePerToken: trade.pricePerToken,
  });

  return trade;
}
