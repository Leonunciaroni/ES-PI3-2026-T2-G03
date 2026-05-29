/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Converte o array bruto de pontos de histórico simulado para o formato usado em `statsLastWindowHours` / exportação da série diária.
 */
/**
 * Lê o campo Firestore `historico_cotacao_sim` (array de pontos) para o formato
 * usado em `statsLastWindowHours` / exportação da série diária.
 */

import {Timestamp} from "firebase-admin/firestore";

import type {PricePoint} from "./startupMarketMath.js";

/**
 * Converte o valor bruto do array guardado pelo [tickStartupMarketPrices]
 * em pontos ordenados por tempo ascendente.
 */
export function parseHistoricoCotacaoSimArray(raw: unknown): PricePoint[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const out: PricePoint[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") {
      continue;
    }
    const m = item as Record<string, unknown>;
    const ts = m["t"];
    let t: Date | null = null;
    if (ts instanceof Timestamp) {
      t = ts.toDate();
    } else if (typeof ts === "string") {
      const d = new Date(ts.trim());
      t = Number.isNaN(d.getTime()) ? null : d;
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
    out.push({t, priceBrl: p});
  }
  out.sort((a, b) => a.t.getTime() - b.t.getTime());
  return out;
}
