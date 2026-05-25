// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
//
// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Cloud Function callable: `simulateWallet`
//
// Objetivo do módulo:
// - Implementar um “saldo fictício” (BRL) para testes/demonstração.
// - Persistir no Firestore em `sim_wallet/{uid}`:
//   - `brlBalance` (saldo disponível)
//   - `ledger/*` (histórico mínimo)
//   - `positions/{startupId}` (posição do investidor)
// - Atualizar `startups/{startupId}` com captação simulada:
//   - soma `amountBrl` nas compras e subtrai nas vendas → `valor_captado_acumulado_brl`
//     (dinheiro líquido agregado de todos os investidores que negociam esta startup);
//   - `progresso_captacao` = captado ÷ `captacao_esperada` (0..1).
//
// Decisões importantes:
// - O cliente não pode escrever diretamente em `sim_wallet` (regras Firestore).
// - Toda atualização é feita via transação (`runTransaction`) para consistência.
// - A cotação (preço do token) é lida do Firestore `startups/{startupId}.preco_token`
//   (fonte de verdade), não do payload do app.

import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

import {
  MAX_OP_BRL,
  REGION,
  ROOT,
  STARTUP_FIELD_CAPTACAO_ESPERADA,
  STARTUP_FIELD_INVESTOR_UIDS,
  STARTUP_FIELD_PROGRESSO_CAPTACAO,
  STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO,
  STARTUPS_COLLECTION,
  USER_FIELD_INVESTOR_STARTUP_IDS,
  USERS_COLLECTION,
} from "../shared/constants.js";
import {
  computeCaptureProgressFraction,
  readOptionalNonNegativeNumber,
} from "../shared/captureProgressMath.js";
import {
  computeSellPositionUpdate,
  mergeBuyPosition,
} from "../shared/positionTradeMath.js";
import {
  assertAmountMatchesTrade,
  assertPositiveIntegerTokens,
  clip,
  readRequiredStartupTokenPriceBrl,
} from "../shared/validation.js";
import {
  readAvailableBrl,
  readAvailableTokens,
  readBrlBalance,
  readTokensHeld,
} from "../../balcao/shared/escrowMath.js";

/**
 * Operações simuladas: crédito interno PIX (demo) + compra/venda de tokens no balcão.
 *
 * Contrato de entrada (request.data):
 * - action:
 *   "credit_pix_simulated" | "withdraw_pix_simulated" | "trade_buy" | "trade_sell"
 * - amountBrl: number (sempre > 0)
 *
 * Para withdraw_pix_simulated (saque simulado):
 * - pixTipo, pixDestHint, headline (opcionais, truncados) para o ledger
 *
 * Para trade:
 * - startupId: string
 * - tokens: number (inteiro positivo)
 * - (metadata opcional para ledger): startupName, tokenSigla, category, headline
 */
export const simulateWallet = onCall({region: REGION}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Precisa iniciar sessão.");
  }

  const actionRaw = typeof request.data?.action === "string"
    ? request.data.action.trim().toLowerCase()
    : "";
  const amountBrl = Number(request.data?.amountBrl);

  if (!Number.isFinite(amountBrl)) {
    throw new HttpsError("invalid-argument", "Valor em reais inválido.");
  }
  if (amountBrl <= 0 || amountBrl > MAX_OP_BRL) {
    throw new HttpsError("invalid-argument", "Valor fora dos limites da simulação.");
  }

  const db = getFirestore();
  const walletRef = db.collection(ROOT).doc(uid);

  if (actionRaw === "credit_pix_simulated") {
    // Crédito simples: soma ao saldo e grava um item no ledger.
    await db.runTransaction(async (trx) => {
      const snap = await trx.get(walletRef);
      const walletData = snap.data() ?? {};
      const prev = typeof walletData.brlBalance === "number"
        ? (walletData.brlBalance as number)
        : 0;
      const next = prev + amountBrl;
      trx.set(walletRef, {brlBalance: next}, {merge: true});
      const ledgerRef = walletRef.collection("ledger").doc();
      trx.create(ledgerRef, {
        op: "credit_pix_simulated",
        dir: "in",
        headline: clip(request.data?.headline, 120) || "Crédito simulado PIX",
        amountBrl,
        startupId: null,
        startupName: null,
        tokenSigla: null,
        tokensQuantity: null,
        tokenPriceBrl: null,
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    logger.info("simulateWallet credit_pix_simulated", {uid, amountBrl});
    return {ok: true};
  }

  if (actionRaw === "withdraw_pix_simulated") {
    const pixTipo = clip(request.data?.pixTipo, 40);
    const pixDestHint = clip(request.data?.pixDestHint, 120);
    const headlineCustom = clip(request.data?.headline, 120);
    const headline =
      headlineCustom ||
      (pixTipo ? `Saque PIX (${pixTipo})` : "Saque PIX simulado");

    await db.runTransaction(async (trx) => {
      const snap = await trx.get(walletRef);
      const walletData = snap.data() ?? {};
      // Saque só pode usar BRL livre (não bloqueado em ordens P2P).
      const disponivel = readAvailableBrl(walletData);

      if (disponivel + 1e-9 < amountBrl) {
        throw new HttpsError(
          "failed-precondition",
          "Saldo insuficiente para este saque simulado."
        );
      }

      const prev = readBrlBalance(walletData);
      const next = prev - amountBrl;
      trx.set(walletRef, {brlBalance: next}, {merge: true});
      const ledgerRef = walletRef.collection("ledger").doc();
      trx.create(ledgerRef, {
        op: "withdraw_pix_simulated",
        dir: "out",
        headline,
        amountBrl,
        startupId: null,
        startupName: null,
        tokenSigla: null,
        tokensQuantity: null,
        tokenPriceBrl: null,
        pixTipo: pixTipo || null,
        pixDestHint: pixDestHint || null,
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    logger.info("simulateWallet withdraw_pix_simulated", {uid, amountBrl});
    return {ok: true};
  }

  if (actionRaw === "trade_buy" || actionRaw === "trade_sell") {
    const tokens = assertPositiveIntegerTokens(request.data?.tokens);
    const startupId = clip(request.data?.startupId, 200);
    if (!startupId) {
      throw new HttpsError("invalid-argument", "startupId obrigatório para negócio.");
    }

    // Cotação oficial: evita manipulação do preço pelo cliente.
    const startupSnap = await db.collection(STARTUPS_COLLECTION).doc(startupId).get();
    if (!startupSnap.exists) {
      throw new HttpsError("not-found", "Startup não encontrada no catálogo.");
    }
    const tokenPriceBrl = readRequiredStartupTokenPriceBrl(startupSnap.data());

    assertAmountMatchesTrade(amountBrl, tokens, tokenPriceBrl);

    const startupName = clip(request.data?.startupName, 200);
    const tokenSigla = clip(request.data?.tokenSigla, 24);
    const category = clip(request.data?.category, 80);

    if (actionRaw === "trade_buy") {
      await db.runTransaction(async (trx) => {
        // Compra:
        // - valida saldo suficiente
        // - decrementa BRL
        // - incrementa posição (tokensHeld/costBasisBrl)
        // - grava ledger
        const ws = await trx.get(walletRef);
        const walletData = ws.data() ?? {};
        const balance = readBrlBalance(walletData);
        // Compra no balcão: respeita BRL bloqueado em ordens P2P de compra.
        const disponivel = readAvailableBrl(walletData);

        if (disponivel + 1e-9 < amountBrl) {
          throw new HttpsError(
            "failed-precondition",
            "Saldo insuficiente para esta compra simulada."
          );
        }

        const positionRef = walletRef.collection("positions").doc(startupId);
        const startupRef = db.collection(STARTUPS_COLLECTION).doc(startupId);
        const posSnap = await trx.get(positionRef);
        const startupTrxSnap = await trx.get(startupRef);
        const posData = posSnap.data() ?? {};
        const prevPos =
          posSnap.exists &&
          (typeof posData.tokensHeld === "number" ||
            typeof posData.costBasisBrl === "number")
            ? {
                tokensHeld:
                  typeof posData.tokensHeld === "number"
                    ? (posData.tokensHeld as number)
                    : 0,
                costBasisBrl:
                  typeof posData.costBasisBrl === "number"
                    ? (posData.costBasisBrl as number)
                    : 0,
              }
            : undefined;
        const {tokensHeld, costBasisBrl} = mergeBuyPosition(
          prevPos,
          tokens,
          amountBrl
        );

        const sd = startupTrxSnap.data() ?? {};
        const esperada =
          readOptionalNonNegativeNumber(sd[STARTUP_FIELD_CAPTACAO_ESPERADA]) ?? 0;
        let captado =
          readOptionalNonNegativeNumber(sd[STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO]) ??
          0;
        captado += amountBrl;
        const progress = computeCaptureProgressFraction(captado, esperada);

        trx.set(walletRef, {brlBalance: balance - amountBrl}, {merge: true});
        trx.set(
          positionRef,
          {
            startupId,
            startupName,
            tokenSigla,
            category,
            tokensHeld,
            costBasisBrl,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );

        const userRef = db.collection(USERS_COLLECTION).doc(uid);
        trx.set(
          userRef,
          {
            [USER_FIELD_INVESTOR_STARTUP_IDS]: FieldValue.arrayUnion(startupId),
          },
          {merge: true}
        );

        trx.set(
          startupRef,
          {
            [STARTUP_FIELD_INVESTOR_UIDS]: FieldValue.arrayUnion(uid),
            [STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO]: captado,
            [STARTUP_FIELD_PROGRESSO_CAPTACAO]: progress,
          },
          {merge: true}
        );

        const investorRef = startupRef.collection("investors").doc(uid);
        trx.set(
          investorRef,
          {
            uid,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true}
        );

        const ledgerRef = walletRef.collection("ledger").doc();
        trx.create(ledgerRef, {
          op: "trade_buy",
          dir: "out",
          headline: tokenSigla
            ? `Compra token (${tokenSigla})`
            : "Compra de token simulado",
          amountBrl,
          startupId,
          startupName,
          tokenSigla,
          tokensQuantity: tokens,
          tokenPriceBrl,
          createdAt: FieldValue.serverTimestamp(),
        });
      });

      logger.info("simulateWallet trade_buy", {uid, startupId, amountBrl});
      return {ok: true};
    }

    await db.runTransaction(async (trx) => {
      // Venda:
      // - valida tokens suficientes
      // - incrementa BRL
      // - decrementa posição proporcionalmente (reduz costBasisBrl)
      // - se tokensHeld zera, apaga o doc da posição
      // - grava ledger
      const ws = await trx.get(walletRef);
      const walletData = ws.data() ?? {};
      const balance = readBrlBalance(walletData);

      const positionRef = walletRef.collection("positions").doc(startupId);
      const startupRef = db.collection(STARTUPS_COLLECTION).doc(startupId);
      const posSnap = await trx.get(positionRef);
      const startupTrxSnap = await trx.get(startupRef);
      const posData = posSnap.data() ?? {};
      const tokensHeldRaw = readTokensHeld(posData);
      const costBasisBrlRaw =
        typeof posData.costBasisBrl === "number"
          ? (posData.costBasisBrl as number)
          : 0;

      if (!posSnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Quantidade insuficiente de tokens nesta startup."
        );
      }

      // Venda no balcão: respeita tokens bloqueados em ordens P2P de venda.
      const tokensDisponiveis = readAvailableTokens(posData);
      if (tokensDisponiveis + 1e-9 < tokens) {
        throw new HttpsError(
          "failed-precondition",
          "Quantidade insuficiente de tokens nesta startup."
        );
      }

      const sellUp = computeSellPositionUpdate(
        {tokensHeld: tokensHeldRaw, costBasisBrl: costBasisBrlRaw},
        tokens
      );
      if (!sellUp.ok) {
        throw new HttpsError(
          "failed-precondition",
          "Quantidade insuficiente de tokens nesta startup."
        );
      }

      const sdSell = startupTrxSnap.data() ?? {};
      const esperadaSell =
        readOptionalNonNegativeNumber(sdSell[STARTUP_FIELD_CAPTACAO_ESPERADA]) ??
        0;
      let captadoSell =
        readOptionalNonNegativeNumber(
          sdSell[STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO]
        ) ?? 0;
      captadoSell = Math.max(0, captadoSell - amountBrl);
      const progressSell = computeCaptureProgressFraction(
        captadoSell,
        esperadaSell
      );

      trx.set(walletRef, {brlBalance: balance + amountBrl}, {merge: true});

      if (sellUp.deletePosition) {
        trx.delete(positionRef);
        const userRef = db.collection(USERS_COLLECTION).doc(uid);
        trx.set(
          userRef,
          {
            [USER_FIELD_INVESTOR_STARTUP_IDS]: FieldValue.arrayRemove(startupId),
          },
          {merge: true}
        );
        trx.set(
          startupRef,
          {
            [STARTUP_FIELD_INVESTOR_UIDS]: FieldValue.arrayRemove(uid),
            [STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO]: captadoSell,
            [STARTUP_FIELD_PROGRESSO_CAPTACAO]: progressSell,
          },
          {merge: true}
        );
        trx.delete(startupRef.collection("investors").doc(uid));
      } else {
        trx.set(
          positionRef,
          {
            startupId,
            startupName,
            tokenSigla,
            category,
            tokensHeld: sellUp.tokensHeld,
            costBasisBrl: sellUp.costBasisBrl,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        trx.set(
          startupRef,
          {
            [STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO]: captadoSell,
            [STARTUP_FIELD_PROGRESSO_CAPTACAO]: progressSell,
          },
          {merge: true}
        );
      }

      const ledgerRef = walletRef.collection("ledger").doc();
      trx.create(ledgerRef, {
        op: "trade_sell",
        dir: "in",
        headline: tokenSigla
          ? `Venda token (${tokenSigla})`
          : "Venda de token simulado",
        amountBrl,
        startupId,
        startupName,
        tokenSigla,
        tokensQuantity: tokens,
        tokenPriceBrl,
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    logger.info("simulateWallet trade_sell", {uid, startupId, amountBrl});
    return {ok: true};
  }

  throw new HttpsError(
    "invalid-argument",
    "Ação não reconhecida. Use credit_pix_simulated, withdraw_pix_simulated, trade_buy ou trade_sell."
  );
});
