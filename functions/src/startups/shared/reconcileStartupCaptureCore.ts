/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Lógica partilhada entre reconcileStartupCapture (uma startup) e
 * reconcileAllStartupsCapture (catálogo inteiro): somar ledgers e gravar no doc.
 */

import type {Firestore} from "firebase-admin/firestore";

import {computeCaptureProgressFraction} from "../../wallet/shared/captureProgressMath.js";
import {
  STARTUP_FIELD_CAPTACAO_ESPERADA,
  STARTUP_FIELD_PROGRESSO_CAPTACAO,
  STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO,
  STARTUPS_COLLECTION,
} from "../../wallet/shared/constants.js";

export function readEsperadaBrl(data: Record<string, unknown> | undefined): number {
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
 * e devolve o total líquido em BRL (compras menos vendas), todos os investidores.
 */
export async function sumLedgerNetBrlForStartup(
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

export type ReconcileOneResult = {
  startupId: string;
  valorCaptadoAcumuladoBrl: number;
  captacaoEsperadaBrl: number | null;
  progressoCaptacao: number;
};

/**
 * Recalcula captado e progresso a partir de todos os extratos e grava em startups/{id}.
 */
export async function reconcileOneStartupDocument(
  db: Firestore,
  startupId: string
): Promise<ReconcileOneResult | null> {
  const startupRef = db.collection(STARTUPS_COLLECTION).doc(startupId);
  const startupSnap = await startupRef.get();
  if (!startupSnap.exists) {
    return null;
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
    startupId,
    valorCaptadoAcumuladoBrl: captadoLiquido,
    captacaoEsperadaBrl: esperada > 0 ? esperada : null,
    progressoCaptacao: progresso,
  };
}
