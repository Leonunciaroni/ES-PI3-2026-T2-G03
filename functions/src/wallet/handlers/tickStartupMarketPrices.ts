/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Cloud Function **agendada**: atualiza `preco_token` e acrescenta um ponto ao histórico
 * simulado de cada startup no catálogo.
 *
 * Intervalo de disparo: ver [MARKET_TICK_SCHEDULE] em `marketSimulationConfig.ts`
 * (padrão **20 minutos** — bom custo/benefício para projeto académico).
 */

import {
  getFirestore,
  type DocumentData,
  type DocumentReference,
  Timestamp,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  REGION,
  STARTUPS_COLLECTION,
  STARTUP_FIELD_HISTORICO_COTACAO_SIM,
  STARTUP_FIELD_TOKEN_PRICE,
} from "../shared/constants.js";
import {nextSimulatedTokenPriceBrl} from "../shared/marketPriceStep.js";
import {
  MARKET_HISTORY_MAX_POINTS,
  MARKET_TICK_SCHEDULE,
} from "../shared/marketSimulationConfig.js";

type CotacaoPonto = {readonly t: Timestamp; readonly p: number};

function readHistorico(data: DocumentData | undefined): CotacaoPonto[] {
  const raw = data?.[STARTUP_FIELD_HISTORICO_COTACAO_SIM];
  if (!Array.isArray(raw)) {
    return [];
  }
  const out: CotacaoPonto[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") {
      continue;
    }
    const m = item as Record<string, unknown>;
    const ts = m["t"];
    let t: Timestamp | null = null;
    if (ts instanceof Timestamp) {
      t = ts;
    } else if (typeof ts === "string") {
      const d = new Date(ts.trim());
      if (!Number.isNaN(d.getTime())) {
        t = Timestamp.fromDate(d);
      }
    }
    const pv = m["p"];
    const p =
      typeof pv === "number"
        ? pv
        : typeof pv === "string"
          ? Number(pv.trim().replace(",", "."))
          : NaN;
    if (t == null || !Number.isFinite(p) || p <= 0) {
      continue;
    }
    out.push({t, p});
  }
  return out;
}

function sortHistorico(points: CotacaoPonto[]): CotacaoPonto[] {
  return [...points].sort((a, b) => a.t.toMillis() - b.t.toMillis());
}

function trimHistorico(points: CotacaoPonto[], maxLen: number): CotacaoPonto[] {
  if (points.length <= maxLen) {
    return points;
  }
  return points.slice(points.length - maxLen);
}

/** Parallel Firestore updates per tick — avoids N sequential round-trips on large catalogs. */
const MARKET_TICK_UPDATE_CONCURRENCY = 15;

async function runWithConcurrency<T>(
  items: T[],
  concurrency: number,
  fn: (item: T) => Promise<void>
): Promise<void> {
  if (items.length === 0) {
    return;
  }
  const limit = Math.max(1, concurrency);
  let index = 0;
  const workers = Array.from({length: Math.min(limit, items.length)}, async () => {
    while (index < items.length) {
      const i = index++;
      await fn(items[i] as T);
    }
  });
  await Promise.all(workers);
}

export const tickStartupMarketPrices = onSchedule(
  {
    schedule: MARKET_TICK_SCHEDULE,
    timeZone: "America/Sao_Paulo",
    region: REGION,
    retryCount: 1,
  },
  async () => {
    const db = getFirestore();
    const snap = await db.collection(STARTUPS_COLLECTION).get();
    const now = Timestamp.now();
    let skipped = 0;

    type UpdateJob = {
      ref: DocumentReference;
      next: number;
      merged: CotacaoPonto[];
    };

    const jobs: UpdateJob[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const rawPrice = data?.[STARTUP_FIELD_TOKEN_PRICE];
      const prev =
        typeof rawPrice === "number"
          ? rawPrice
          : typeof rawPrice === "string"
            ? Number(rawPrice.trim().replace(",", "."))
            : NaN;
      if (!Number.isFinite(prev) || prev <= 0) {
        skipped++;
        continue;
      }

      const next = nextSimulatedTokenPriceBrl(prev);
      const anterior = sortHistorico(readHistorico(data));
      const novoPonto: CotacaoPonto = {t: now, p: next};
      const merged = trimHistorico([...anterior, novoPonto], MARKET_HISTORY_MAX_POINTS);

      jobs.push({ref: doc.ref, next, merged});
    }

    await runWithConcurrency(jobs, MARKET_TICK_UPDATE_CONCURRENCY, async (job) => {
      await job.ref.update({
        [STARTUP_FIELD_TOKEN_PRICE]: job.next,
        [STARTUP_FIELD_HISTORICO_COTACAO_SIM]: job.merged.map((x) => ({
          t: x.t,
          p: x.p,
        })),
      });
    });

    const updated = jobs.length;

    logger.info("tickStartupMarketPrices", {
      startupsTotal: snap.size,
      updated,
      skipped,
      schedule: MARKET_TICK_SCHEDULE,
    });
  }
);
