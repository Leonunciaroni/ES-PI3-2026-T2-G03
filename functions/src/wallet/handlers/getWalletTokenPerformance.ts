/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Callable HTTPS: `getWalletTokenPerformance`
 *
 * Enquadramento (documento MesclaInvest / PI3):
 * - §5.4: acompanhar **valorização dos tokens** com base nas **transações simuladas**.
 * - §5.6: sem blockchain real — usamos o **ledger** em Firestore como “registo
 *   auditável” das operações (analogia pedagógica com a ideia de rastreio da §3).
 *
 * Contrato de entrada (`request.data`):
 * - `period`: string — um de `diario` | `semanal` | `mensal` | `seisMeses` | `ytd`
 *   (mesmo nome que o enum Dart `ValuationPeriod`).
 *
 * Resposta:
 * - `{ data: { sampleTimesIso, valuesBrl, changePctPeriod, minBrl, maxBrl, trendLabel,
 *      costBasisBrl, marketValueNowBrl, footnote } }`
 */

import {
  getFirestore,
  type DocumentData,
  type QueryDocumentSnapshot,
  Timestamp,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";

import {requireAuthenticatedUser} from "../../startups/shared/auth.js";
import {
  REGION,
  ROOT,
  STARTUPS_COLLECTION,
} from "../shared/constants.js";
import {readRequiredStartupTokenPriceBrl} from "../shared/validation.js";
import {
  buildWalletTokenPerformanceSeries,
  type LedgerTradeRow,
  parseWalletPeriod,
} from "../shared/tokenPerformanceMath.js";

function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) {
    return v.toDate();
  }
  if (
    v &&
    typeof v === "object" &&
    "toDate" in (v as object) &&
    typeof (v as Timestamp).toDate === "function"
  ) {
    return (v as Timestamp).toDate();
  }
  return null;
}

function ledgerRowsFromDocs(
  docs: readonly QueryDocumentSnapshot<DocumentData>[]
): LedgerTradeRow[] {
  const rows: LedgerTradeRow[] = [];
  for (const d of docs) {
    const m = d.data();
    const op = m["op"];
    if (op !== "trade_buy" && op !== "trade_sell") {
      continue;
    }
    const at = toDate(m["createdAt"]);
    if (!at) {
      continue;
    }
    const startupId = typeof m["startupId"] === "string" ? m["startupId"].trim() : "";
    if (!startupId) {
      continue;
    }
    const tokensQuantity = Number(m["tokensQuantity"]);
    const tokenPriceBrl = Number(m["tokenPriceBrl"]);
    if (!Number.isFinite(tokensQuantity) || tokensQuantity <= 0) {
      continue;
    }
    if (!Number.isFinite(tokenPriceBrl) || tokenPriceBrl <= 0) {
      continue;
    }
    rows.push({
      at,
      op,
      startupId,
      tokensQuantity,
      tokenPriceBrl,
    });
  }
  rows.sort((a, b) => a.at.getTime() - b.at.getTime());
  return rows;
}

export const getWalletTokenPerformance = onCall({region: REGION}, async (request) => {
  const user = requireAuthenticatedUser(request);
  const period = parseWalletPeriod(request.data?.period);
  if (!period) {
    throw new HttpsError(
      "invalid-argument",
      "Informe period: diario | semanal | mensal | seisMeses | ytd."
    );
  }

  const db = getFirestore();
  const walletRef = db.collection(ROOT).doc(user.uid);

  const ledgerSnap = await walletRef
    .collection("ledger")
    .orderBy("createdAt", "desc")
    .limit(500)
    .get();

  const tradesAsc = ledgerRowsFromDocs([...ledgerSnap.docs].reverse());

  const positionsSnap = await walletRef.collection("positions").get();
  const startupIds = new Set<string>();
  for (const d of positionsSnap.docs) {
    startupIds.add(d.id);
  }
  for (const r of tradesAsc) {
    startupIds.add(r.startupId);
  }

  const priceMap = new Map<string, number>();
  const refs = [...startupIds].map((id) =>
    db.collection(STARTUPS_COLLECTION).doc(id)
  );
  if (refs.length > 0) {
    const snaps = await db.getAll(...refs);
    for (const s of snaps) {
      if (!s.exists) {
        continue;
      }
      try {
        const p = readRequiredStartupTokenPriceBrl(s.data());
        priceMap.set(s.id, p);
      } catch {
        // startup sem preço: ignoramos na série (tokens dessa id ficam com preço 0)
      }
    }
  }

  let costBasisBrl = 0;
  let marketValueNowBrl = 0;
  const now = new Date();
  for (const d of positionsSnap.docs) {
    const m = d.data();
    const held = typeof m["tokensHeld"] === "number" ? m["tokensHeld"] : Number(m["tokensHeld"]);
    const cost =
      typeof m["costBasisBrl"] === "number" ? m["costBasisBrl"] : Number(m["costBasisBrl"]);
    if (Number.isFinite(cost) && cost > 0) {
      costBasisBrl += cost;
    }
    const sid = d.id;
    const px = priceMap.get(sid) ?? 0;
    if (Number.isFinite(held) && held > 0 && px > 0) {
      marketValueNowBrl += held * px;
    }
  }

  const series = buildWalletTokenPerformanceSeries(
    period,
    now,
    tradesAsc,
    priceMap,
    7
  );

  const footnote =
    "Valores calculados no servidor a partir do extrato simulado (compras/vendas). " +
    "Instantes em UTC; preço antes da 1.ª negociação usa a cotação atual do catálogo.";

  return {
    data: {
      period,
      sampleTimesIso: series.sampleTimesIso,
      valuesBrl: series.valuesBrl,
      changePctPeriod: series.changePctFirstLast,
      minBrl: series.minBrl,
      maxBrl: series.maxBrl,
      trendLabel: series.trendLabel,
      costBasisBrl,
      marketValueNowBrl,
      footnote,
    },
  };
});
