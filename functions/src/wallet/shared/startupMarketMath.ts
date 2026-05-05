/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Cotação do token no “mercado simulado” a partir do documento `startups/{id}`:
 * - `preco_token`: última cotação oficial (mesma fonte que a negociação).
 * - `grafico_valuation.diario`: pontos históricos (valuation em milhões ou outra unidade),
 *   escalados para BRL/token proporcionalmente, ancorando o **último** ponto em `preco_token`.
 *
 * Isto aproxima o visual de uma corretora sem usar blockchain real (fora do §5.6).
 */

export type PricePoint = { readonly t: Date; readonly priceBrl: number };

/**
 * Escala a série de valuation para preço do token em BRL (último ponto = precoAtual).
 */
export function cotacaoBrlFromValuationSeries(
  valuations: readonly number[],
  times: readonly Date[],
  precoAtualBrl: number
): PricePoint[] {
  if (valuations.length === 0 || valuations.length !== times.length) {
    return [];
  }
  const last = valuations[valuations.length - 1]!;
  if (!Number.isFinite(last) || Math.abs(last) < 1e-12) {
    return times.map((t) => ({t, priceBrl: precoAtualBrl}));
  }
  const out: PricePoint[] = [];
  for (let i = 0; i < valuations.length; i++) {
    const t = times[i];
    const v = valuations[i];
    if (t === undefined || v === undefined) {
      continue;
    }
    out.push({
      t,
      priceBrl: precoAtualBrl * (v / last),
    });
  }
  return out;
}

/**
 * Interpola o preço no instante [target] (UTC) assumindo segmentos lineares entre pontos.
 */
export function interpolatePriceBrl(
  seriesAsc: readonly PricePoint[],
  target: Date
): number | null {
  if (seriesAsc.length === 0) {
    return null;
  }
  const x = target.getTime();
  const first = seriesAsc[0];
  const last = seriesAsc[seriesAsc.length - 1];
  if (!first || !last) {
    return null;
  }
  if (x <= first.t.getTime()) {
    return first.priceBrl;
  }
  if (x >= last.t.getTime()) {
    return last.priceBrl;
  }
  for (let i = 0; i < seriesAsc.length - 1; i++) {
    const a = seriesAsc[i];
    const b = seriesAsc[i + 1];
    if (!a || !b) {
      continue;
    }
    const ta = a.t.getTime();
    const tb = b.t.getTime();
    if (x >= ta && x <= tb) {
      if (tb <= ta) {
        return a.priceBrl;
      }
      const w = (x - ta) / (tb - ta);
      return a.priceBrl + w * (b.priceBrl - a.priceBrl);
    }
  }
  return last.priceBrl;
}

export type MarketWindow24hStats = {
  readonly changePct24h: number | null;
  readonly minBrl: number | null;
  readonly maxBrl: number | null;
};

/**
 * Variação % numa janela móvel de 24h ancorada no **último** instante da série
 * (útil quando o gráfico “diário” tem mais do que um dia de amostras).
 */
export function statsLastWindowHours(
  seriesAsc: readonly PricePoint[],
  windowHours = 24
): MarketWindow24hStats {
  if (seriesAsc.length < 2) {
    return {changePct24h: null, minBrl: null, maxBrl: null};
  }
  const last = seriesAsc[seriesAsc.length - 1];
  if (!last) {
    return {changePct24h: null, minBrl: null, maxBrl: null};
  }
  const anchor = last.t.getTime();
  const start = anchor - windowHours * 3600 * 1000;

  const refPrice = interpolatePriceBrl(seriesAsc, new Date(start));
  const endPrice = last.priceBrl;
  let changePct: number | null = null;
  if (
    refPrice != null &&
    Number.isFinite(refPrice) &&
    Math.abs(refPrice) > 1e-12 &&
    Number.isFinite(endPrice)
  ) {
    const p = ((endPrice - refPrice) / refPrice) * 100;
    changePct = Number.isFinite(p) ? p : null;
  }

  const candidates: number[] = [endPrice];
  if (refPrice != null && Number.isFinite(refPrice)) {
    candidates.push(refPrice);
  }
  for (const pt of seriesAsc) {
    const tx = pt.t.getTime();
    if (tx >= start && tx <= anchor) {
      candidates.push(pt.priceBrl);
    }
  }
  const minB = candidates.length ? Math.min(...candidates) : null;
  const maxB = candidates.length ? Math.max(...candidates) : null;

  return {changePct24h: changePct, minBrl: minB, maxBrl: maxB};
}

function readOptionalNumber(v: unknown): number | undefined {
  if (typeof v === "number" && Number.isFinite(v)) {
    return v;
  }
  if (typeof v === "string") {
    const n = Number(v.trim().replace(",", "."));
    return Number.isFinite(n) ? n : undefined;
  }
  return undefined;
}

/**
 * Extrai lista (t, v) do mapa `grafico_valuation` na chave `diario` (ou `Diario`).
 */
export function parseGraficoValuationDiario(
  graficoValuation: unknown
): { t: Date; v: number }[] | null {
  if (!graficoValuation || typeof graficoValuation !== "object") {
    return null;
  }
  const g = graficoValuation as Record<string, unknown>;
  const rawList = g["diario"] ?? g["Diario"];
  if (!Array.isArray(rawList)) {
    return null;
  }
  const out: { t: Date; v: number }[] = [];
  for (const item of rawList) {
    if (!item || typeof item !== "object") {
      continue;
    }
    const m = item as Record<string, unknown>;
    const ts = m["t"];
    if (typeof ts !== "string") {
      continue;
    }
    const t = new Date(ts);
    if (Number.isNaN(t.getTime())) {
      continue;
    }
    const v =
      readOptionalNumber(m["v"]) ?? readOptionalNumber(m["valor"]);
    if (v == null) {
      continue;
    }
    out.push({t, v});
  }
  if (out.length === 0) {
    return null;
  }
  out.sort((a, b) => a.t.getTime() - b.t.getTime());
  return out;
}
