import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

const REGION = "us-central1";

const ROOT = "sim_wallet";
const STARTUPS_COLLECTION = "startups";
const STARTUP_FIELD_TOKEN_PRICE = "preco_token";
const MAX_OP_BRL = 50_000_000;
const EPSILON_BRL = 0.06;

/** Valida total ≈ tokens * preço (tolerância de arredondamento). */
function assertAmountMatchesTrade(
  amountBrl: number,
  tokens: number,
  tokenPriceBrl: number
): void {
  if (tokens <= 0 || !Number.isFinite(tokens)) {
    throw new HttpsError("invalid-argument", "Informe uma quantidade de tokens válida.");
  }
  if (tokenPriceBrl <= 0 || !Number.isFinite(tokenPriceBrl)) {
    throw new HttpsError("invalid-argument", "Preço por token inválido.");
  }
  const implied = tokens * tokenPriceBrl;
  if (Math.abs(amountBrl - implied) > EPSILON_BRL) {
    throw new HttpsError(
      "failed-precondition",
      "Valor em reais e quantidade de tokens não conferem com a cotação."
    );
  }
}

/** Recorta strings vindas da app antes de gravar nos documentos auditáveis. */
function clip(s: unknown, max: number): string {
  if (typeof s !== "string") {
    return "";
  }
  const t = s.trim();
  return t.length > max ? t.slice(0, max) : t;
}

function readRequiredStartupTokenPriceBrl(
  startupSnapData: FirebaseFirestore.DocumentData | undefined
): number {
  const raw = startupSnapData?.[STARTUP_FIELD_TOKEN_PRICE];
  const p = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(p) || p <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "Cotação do token indisponível para esta startup."
    );
  }
  return p;
}

/** Operações simuladas: crédito interno PIX (demo) + compra/venda de tokens no balcão. */
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
    await db.runTransaction(async (trx) => {
      const snap = await trx.get(walletRef);
      const prev = typeof snap.data()?.brlBalance === "number"
        ? (snap.data()!.brlBalance as number)
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

  if (actionRaw === "trade_buy" || actionRaw === "trade_sell") {
    const tokens = Number(request.data?.tokens);
    const startupId = clip(request.data?.startupId, 200);
    if (!startupId) {
      throw new HttpsError("invalid-argument", "startupId obrigatório para negócio.");
    }

    // Fonte de verdade: cotação vem do Firestore (não confiar no cliente).
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
        const ws = await trx.get(walletRef);
        const balance =
          typeof ws.data()?.brlBalance === "number"
            ? (ws.data()!.brlBalance as number)
            : 0;

        if (balance + 1e-9 < amountBrl) {
          throw new HttpsError(
            "failed-precondition",
            "Saldo insuficiente para esta compra simulada."
          );
        }

        const positionRef = walletRef.collection("positions").doc(startupId);
        const posSnap = await trx.get(positionRef);
        let tokensHeld =
          typeof posSnap.data()?.tokensHeld === "number"
            ? (posSnap.data()!.tokensHeld as number)
            : 0;
        let costBasisBrl =
          typeof posSnap.data()?.costBasisBrl === "number"
            ? (posSnap.data()!.costBasisBrl as number)
            : 0;

        tokensHeld += tokens;
        costBasisBrl += amountBrl;

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

    // trade_sell
    await db.runTransaction(async (trx) => {
      const ws = await trx.get(walletRef);
      const balance =
        typeof ws.data()?.brlBalance === "number"
          ? (ws.data()!.brlBalance as number)
          : 0;

      const positionRef = walletRef.collection("positions").doc(startupId);
      const posSnap = await trx.get(positionRef);
      let tokensHeld =
        typeof posSnap.data()?.tokensHeld === "number"
          ? (posSnap.data()!.tokensHeld as number)
          : 0;
      const costBasisBrl =
        typeof posSnap.data()?.costBasisBrl === "number"
          ? (posSnap.data()!.costBasisBrl as number)
          : 0;

      if (!posSnap.exists || tokensHeld < tokens - 1e-12) {
        throw new HttpsError(
          "failed-precondition",
          "Quantidade insuficiente de tokens nesta startup."
        );
      }

      const costRemoved =
        tokensHeld <= 1e-12 ? 0 : costBasisBrl * (tokens / tokensHeld);

      tokensHeld -= tokens;

      trx.set(walletRef, {brlBalance: balance + amountBrl}, {merge: true});

      const newCost = Math.max(0, costBasisBrl - costRemoved);

      if (tokensHeld <= 1e-9) {
        trx.delete(positionRef);
      } else {
        trx.set(
          positionRef,
          {
            startupId,
            startupName,
            tokenSigla,
            category,
            tokensHeld,
            costBasisBrl: newCost,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
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
    "Ação não reconhecida. Use credit_pix_simulated, trade_buy ou trade_sell."
  );
});

// Export interno para testes unitários.
export const __test__ = {
  assertAmountMatchesTrade,
  clip,
  readRequiredStartupTokenPriceBrl,
};
