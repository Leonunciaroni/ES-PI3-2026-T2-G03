// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Executa um match P2P entre ordem de venda e compra dentro de runTransaction.

import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

import {syncOpenOrderIndexFromRef} from "../repositories/userOrderIndex.js";
import {
  ORDER_FIELD_PRICE,
  ORDER_FIELD_QUANTITY,
  ORDER_FIELD_STATUS,
  POSITION_FIELD_TOKENS_LOCKED,
  STARTUP_FIELD_INVESTOR_UIDS,
  STARTUPS_COLLECTION,
  USER_FIELD_INVESTOR_STARTUP_IDS,
  USERS_COLLECTION,
  WALLET_FIELD_BRL_LOCKED,
  WALLET_ROOT,
} from "./constants.js";
import {
  readBrlBalance,
  readBrlLocked,
  readTokensHeld,
  readTokensLocked,
} from "./escrowMath.js";
import {db} from "./firebase.js";
import {
  StatusOrdem,
  TipoOrdem,
  type ExecuteP2pMatchResult,
  type OrdemMatchCandidate,
} from "../types/index.js";
import {
  computeSellPositionUpdate,
  mergeBuyPosition,
} from "../../wallet/shared/positionTradeMath.js";

/**
 * Executa negócio P2P entre uma ordem de venda e uma de compra.
 *
 * Retorna `{ matched: false }` se as ordens não puderem ser executadas
 * (ex.: saldo insuficiente no momento) — o match engine tenta outro par.
 */
export async function executeP2pMatch(
  startupId: string,
  sell: OrdemMatchCandidate,
  buy: OrdemMatchCandidate
): Promise<ExecuteP2pMatchResult> {
  if (sell.uid === buy.uid) {
    return {matched: false, reason: "self_trade_blocked"};
  }

  if (sell.pricePerToken > buy.pricePerToken + 1e-12) {
    return {matched: false, reason: "price_no_cross"};
  }

  try {
    await db.runTransaction(async (trx) => {
      const sellSnap = await trx.get(sell.ref);
      const buySnap = await trx.get(buy.ref);

      if (!sellSnap.exists || !buySnap.exists) {
        throw new HttpsError("aborted", "Ordem removida.");
      }

      const sellData = sellSnap.data() ?? {};
      const buyData = buySnap.data() ?? {};

      if (sellData[ORDER_FIELD_STATUS] !== StatusOrdem.Aberta ||
          buyData[ORDER_FIELD_STATUS] !== StatusOrdem.Aberta) {
        throw new HttpsError("aborted", "Ordem já não está aberta.");
      }

      const sellQty = Number(sellData[ORDER_FIELD_QUANTITY]);
      const buyQty = Number(buyData[ORDER_FIELD_QUANTITY]);
      const sellPrice = Number(sellData[ORDER_FIELD_PRICE]);
      const buyPrice = Number(buyData[ORDER_FIELD_PRICE]);

      if (!Number.isInteger(sellQty) || sellQty <= 0 ||
          !Number.isInteger(buyQty) || buyQty <= 0) {
        throw new HttpsError("aborted", "Quantidade inválida.");
      }

      if (sellPrice > buyPrice + 1e-12) {
        throw new HttpsError("aborted", "Preços não cruzam.");
      }

      const sellCreated = sellData.createdAt as Timestamp | undefined;
      const buyCreated = buyData.createdAt as Timestamp | undefined;

      // Preço da ordem mais antiga (quem chegou primeiro).
      let executionPrice = sellPrice;
      if (sellCreated && buyCreated) {
        executionPrice =
          sellCreated.toMillis() <= buyCreated.toMillis() ? sellPrice : buyPrice;
      } else if (buyCreated && !sellCreated) {
        executionPrice = buyPrice;
      }

      const tradeQty = Math.min(sellQty, buyQty);
      const amountBrl = tradeQty * executionPrice;

      const buyerWalletRef = db.collection(WALLET_ROOT).doc(buy.uid);
      const sellerWalletRef = db.collection(WALLET_ROOT).doc(sell.uid);
      const buyerPosRef = buyerWalletRef.collection("positions").doc(startupId);
      const sellerPosRef = sellerWalletRef.collection("positions").doc(startupId);
      const startupRef = db.collection(STARTUPS_COLLECTION).doc(startupId);

      const [buyerWalletSnap, sellerWalletSnap, buyerPosSnap, sellerPosSnap] =
        await Promise.all([
          trx.get(buyerWalletRef),
          trx.get(sellerWalletRef),
          trx.get(buyerPosRef),
          trx.get(sellerPosRef),
        ]);

      const buyerWallet = buyerWalletSnap.data() ?? {};
      const sellerWallet = sellerWalletSnap.data() ?? {};
      const sellerPos = sellerPosSnap.data() ?? {};

      const buyerBalance = readBrlBalance(buyerWallet);
      const buyerLocked = readBrlLocked(buyerWallet);
      const sellerHeld = readTokensHeld(sellerPos);
      const sellerLocked = readTokensLocked(sellerPos);

      if (buyerBalance + 1e-9 < amountBrl) {
        throw new HttpsError("aborted", "Comprador sem saldo.");
      }
      if (buyerLocked + 1e-9 < amountBrl) {
        throw new HttpsError("aborted", "Comprador sem escrow.");
      }
      if (sellerHeld + 1e-9 < tradeQty) {
        throw new HttpsError("aborted", "Vendedor sem tokens.");
      }
      if (sellerLocked + 1e-9 < tradeQty) {
        throw new HttpsError("aborted", "Vendedor sem escrow.");
      }

      const startupName =
        (typeof sellData.startupName === "string" ? sellData.startupName : "") ||
        (typeof buyData.startupName === "string" ? buyData.startupName : "");
      const tokenSigla =
        (typeof sellData.tokenSigla === "string" ? sellData.tokenSigla : "") ||
        (typeof buyData.tokenSigla === "string" ? buyData.tokenSigla : "");
      const category =
        typeof sellerPos.category === "string" ? sellerPos.category : null;

      // --- Comprador: debita BRL + escrow, incrementa posição ---
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

      trx.set(
        buyerWalletRef,
        {
          brlBalance: buyerBalance - amountBrl,
          [WALLET_FIELD_BRL_LOCKED]: Math.max(0, buyerLocked - amountBrl),
        },
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

      const buyerUserRef = db.collection(USERS_COLLECTION).doc(buy.uid);
      trx.set(
        buyerUserRef,
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

      // --- Vendedor: credita BRL, decrementa tokens + escrow ---
      const sellUp = computeSellPositionUpdate(
        {
          tokensHeld: sellerHeld,
          costBasisBrl:
            typeof sellerPos.costBasisBrl === "number" ? sellerPos.costBasisBrl : 0,
        },
        tradeQty
      );

      if (!sellUp.ok) {
        throw new HttpsError("aborted", "Vendedor sem tokens suficientes.");
      }

      trx.set(
        sellerWalletRef,
        {brlBalance: readBrlBalance(sellerWallet) + amountBrl},
        {merge: true}
      );

      if (sellUp.deletePosition) {
        trx.delete(sellerPosRef);
        const sellerUserRef = db.collection(USERS_COLLECTION).doc(sell.uid);
        trx.set(
          sellerUserRef,
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
            category,
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

      // --- Startup: investidores (captação líquida inalterada em P2P entre pares) ---
      if (sellUp.deletePosition) {
        trx.set(
          startupRef,
          {[STARTUP_FIELD_INVESTOR_UIDS]: FieldValue.arrayRemove(sell.uid)},
          {merge: true}
        );
        trx.delete(startupRef.collection("investors").doc(sell.uid));
      }

      trx.set(
        startupRef,
        {[STARTUP_FIELD_INVESTOR_UIDS]: FieldValue.arrayUnion(buy.uid)},
        {merge: true}
      );

      trx.set(
        startupRef.collection("investors").doc(buy.uid),
        {uid: buy.uid, updatedAt: FieldValue.serverTimestamp()},
        {merge: true}
      );

      // --- Atualiza ordens (parcial ou total) ---
      const sellRemaining = sellQty - tradeQty;
      const buyRemaining = buyQty - tradeQty;

      if (sellRemaining <= 0) {
        trx.update(sell.ref, {[ORDER_FIELD_STATUS]: StatusOrdem.Executada});
      } else {
        trx.update(sell.ref, {[ORDER_FIELD_QUANTITY]: sellRemaining});
      }

      if (buyRemaining <= 0) {
        trx.update(buy.ref, {[ORDER_FIELD_STATUS]: StatusOrdem.Executada});
      } else {
        trx.update(buy.ref, {[ORDER_FIELD_QUANTITY]: buyRemaining});
      }
    });

    await Promise.all([
      syncOpenOrderIndexFromRef(sell.ref, TipoOrdem.Venda),
      syncOpenOrderIndexFromRef(buy.ref, TipoOrdem.Compra),
    ]);

    logger.info("executeP2pMatch ok", {
      startupId,
      sellId: sell.id,
      buyId: buy.id,
    });
    return {matched: true};
  } catch (err) {
    if (err instanceof HttpsError && err.code === "aborted") {
      logger.warn("executeP2pMatch skipped", {
        startupId,
        sellId: sell.id,
        buyId: buy.id,
        reason: err.message,
      });
      return {matched: false, reason: err.message ?? "aborted"};
    }
    throw err;
  }
}
