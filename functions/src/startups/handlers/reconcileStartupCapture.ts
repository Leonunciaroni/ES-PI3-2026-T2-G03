/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Callable reconcileStartupCapture — recalcula valor_captado_acumulado_brl e
 * progresso_captacao no documento startups/{id} somando todas as linhas do
 * extrato simulado (subcoleção ledger em cada sim_wallet) dessa startup.
 *
 * Porquê existe:
 * - O fluxo normal já atualiza estes campos em cada compra/venda (simulateWallet);
 * - esta função serve para corrigir divergências ou depois de dados antigos sem contador.
 *
 * Investimento total = soma de amountBrl em trade_buy menos trade_sell,
 * para todos os utilizadores (cada carteira tem o seu ledger).
 */
import type {Firestore} from "firebase-admin/firestore";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";

import {requireAuthenticatedUser} from "../shared/auth.js";
import {normalizeString} from "../shared/validation.js";
import {computeCaptureProgressFraction} from "../../wallet/shared/captureProgressMath.js";
import {
  STARTUP_FIELD_CAPTACAO_ESPERADA,
  STARTUP_FIELD_PROGRESSO_CAPTACAO,
  STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO,
  STARTUPS_COLLECTION,
} from "../../wallet/shared/constants.js";

function readEsperadaBrl(data: Record<string, unknown> | undefined): number {
  if (!data) {
    return 0;
  }
  const raw = data[STARTUP_FIELD_CAPTACAO_ESPERADA];
  if (typeof raw === "number" && Number.isFinite(raw) && raw > 0) {
    return raw;
  }
  if (typeof raw === "string") {
    const n = Number(raw.trim().replace(",", "."));
    return Number.isFinite(n) && n > 0 ? n : 0;
  }
  return 0;
}

/**
 * Percorre todos os documentos ledger (collection group) com este startupId
 * e devolve o total líquido em BRL (compras menos vendas).
 */async function sumLedgerNetBrlForStartup(
  db: Firestore,
  startupId: string
): Promise<number> {
  const snap = await db
    .collectionGroup("ledger")
    .where("startupId", "==", startupId)
    .get();

  let captado = 0;
  for (const doc of snap.docs) {
    const m = doc.data() as Record<string, unknown>;
    const op = typeof m.op === "string" ? m.op.trim().toLowerCase() : "";
    const amtRaw = m.amountBrl;
    const amt =
      typeof amtRaw === "number" && Number.isFinite(amtRaw)
        ? amtRaw
        : typeof amtRaw === "string"
          ? Number(amtRaw.trim().replace(",", "."))
          : NaN;
    if (!Number.isFinite(amt)) {
      continue;
    }
    if (op === "trade_buy") {
      captado += amt;
    } else if (op === "trade_sell") {
      captado -= amt;
    }
  }
  return Math.max(0, captado);
}

export const reconcileStartupCapture = onCall({region: "us-central1"}, async (request) => {
  requireAuthenticatedUser(request);

  const startupId = normalizeString(request.data?.startupId);
  if (!startupId) {
    throw new HttpsError(
      "invalid-argument",
      "Informe startupId para reconciliar a captação."
    );
  }

  const db = getFirestore();
  const startupRef = db.collection(STARTUPS_COLLECTION).doc(startupId);
  const startupSnap = await startupRef.get();
  if (!startupSnap.exists) {
    throw new HttpsError("not-found", "Startup não encontrada.");
  }

  const sd = startupSnap.data() as Record<string, unknown>;
  const esperada = readEsperadaBrl(sd);

  const captadoLiquido = await sumLedgerNetBrlForStartup(db, startupId);
  const progresso = computeCaptureProgressFraction(captadoLiquido, esperada);

  await startupRef.set(
    {
      [STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO]: captadoLiquido,
      [STARTUP_FIELD_PROGRESSO_CAPTACAO]: progresso,
    },
    {merge: true}
  );

  return {
    ok: true,
    startupId,
    valorCaptadoAcumuladoBrl: captadoLiquido,
    captacaoEsperadaBrl: esperada > 0 ? esperada : null,
    progressoCaptacao: progresso,
  };
});
