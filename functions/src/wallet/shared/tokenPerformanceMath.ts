/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Matemática pura da valorização da **carteira de tokens** (Projeto Integrador 3).
 *
 * Contexto do documento MesclaInvest (PDF de visão):
 * - §5.4: o investidor acompanha variação em vários períodos; os valores devem refletir
 *   as **transações simuladas** registadas no sistema (ledger).
 * - §3 (blockchain): no mundo real, transferências ficam num registo auditável; aqui
 *   **imitamos** essa ideia com linhas imutáveis no Firestore (`sim_wallet/.../ledger`),
 *   sem rede blockchain (isso está fora do âmbito no §5.6 do PDF).
 *
 * Modelo pedagógico (simples de explicar na banca):
 * 1. Ordenamos compras/vendas por data.
 * 2. Para cada instante da amostra, simulamos “quantos tokens tinhas naquele momento”
 *    (soma das compras − vendas até à data).
 * 3. O preço usado em cada instante é o da **última negociação** daquela startup até
 *    essa data (`tokenPriceBrl` gravado no ledger); se ainda não havia negócio, usamos
 *    o `preco_token` atual do catálogo (não há histórico de mercado mais fino no PI).
 * 4. Valor da carteira de tokens = soma(tokens da startup × preço daquele instante).
 */

/** Períodos iguais aos chips do app Flutter (`ValuationPeriod.name`). */
export type WalletPerformancePeriod =
  | "diario"
  | "semanal"
  | "mensal"
  | "seisMeses"
  | "ytd";

export type LedgerTradeRow = {
  readonly at: Date;
  readonly op: "trade_buy" | "trade_sell";
  readonly startupId: string;
  readonly tokensQuantity: number;
  readonly tokenPriceBrl: number;
};

/** Início do dia civil local (interpretado no fuso do servidor = UTC nas Functions). */
function inicioDiaUtc(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

/** Segunda-feira 00:00 UTC da semana que contém [d] (Dart: weekday 1 = segunda). */
function inicioSemanaUtc(d: Date): Date {
  const sod = inicioDiaUtc(d);
  const dow = d.getUTCDay(); // 0 domingo … 6 sábado
  const dartWeek = dow === 0 ? 7 : dow;
  const monday = new Date(sod);
  monday.setUTCDate(sod.getUTCDate() - (dartWeek - 1));
  return monday;
}

function inicioMesUtc(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1));
}

function inicioSeisMesesUtc(d: Date): Date {
  const sod = inicioDiaUtc(d);
  const x = new Date(sod);
  x.setUTCDate(x.getUTCDate() - 183);
  return x;
}

function inicioYtdUtc(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
}

/**
 * Início da janela temporal do período (alinhado à [CarteiraScreen] em Dart).
 */
export function periodWindowStartUtc(period: WalletPerformancePeriod, now: Date): Date {
  switch (period) {
    case "diario":
      return inicioDiaUtc(now);
    case "semanal":
      return inicioSemanaUtc(now);
    case "mensal":
      return inicioMesUtc(now);
    case "seisMeses":
      return inicioSeisMesesUtc(now);
    case "ytd":
      return inicioYtdUtc(now);
    default:
      return inicioMesUtc(now);
  }
}

/** Valida string vinda da callable; devolve null se for inválida. */
export function parseWalletPeriod(raw: unknown): WalletPerformancePeriod | null {
  if (typeof raw !== "string") {
    return null;
  }
  const p = raw.trim();
  switch (p) {
    case "diario":
    case "semanal":
    case "mensal":
    case "seisMeses":
    case "ytd":
      return p;
    default:
      return null;
  }
}

/**
 * Gera [count] instantes entre [inicio] e [fim] (inclusive), como o gráfico da carteira.
 */
export function sampleInstantsUtc(
  inicio: Date,
  fim: Date,
  count = 7
): Date[] {
  const n = Math.max(2, count);
  const a = inicio.getTime();
  const b = fim.getTime();
  if (!(b > a)) {
    return [inicio, fim];
  }
  const out: Date[] = [];
  for (let i = 0; i < n; i++) {
    const t = a + Math.round(((b - a) * i) / (n - 1));
    out.push(new Date(t));
  }
  return out;
}

export function replayTokenHoldingsAt(
  tradesAsc: readonly LedgerTradeRow[],
  deadline: Date
): Map<string, number> {
  const h = new Map<string, number>();
  for (const r of tradesAsc) {
    if (r.at > deadline) {
      break;
    }
    const sid = r.startupId;
    const prev = h.get(sid) ?? 0;
    if (r.op === "trade_buy") {
      h.set(sid, prev + r.tokensQuantity);
    } else {
      h.set(sid, prev - r.tokensQuantity);
    }
  }
  return h;
}

/**
 * Último preço registado numa operação da startup até [deadline], senão [fallbackPrice].
 */
export function lastTradePriceBefore(
  tradesAsc: readonly LedgerTradeRow[],
  startupId: string,
  deadline: Date,
  fallbackPrice: number
): number {
  let last: number | null = null;
  for (const r of tradesAsc) {
    if (r.at > deadline) {
      break;
    }
    if (r.startupId !== startupId) {
      continue;
    }
    if (r.tokenPriceBrl > 0 && Number.isFinite(r.tokenPriceBrl)) {
      last = r.tokenPriceBrl;
    }
  }
  if (last != null) {
    return last;
  }
  return fallbackPrice > 0 && Number.isFinite(fallbackPrice) ? fallbackPrice : 0;
}

/**
 * Valor de mercado da carteira **só de tokens** (sem saldo livre em BRL).
 */
export function portfolioTokenMarketValueBrl(
  tradesAsc: readonly LedgerTradeRow[],
  deadline: Date,
  currentTokenPriceByStartup: ReadonlyMap<string, number>
): number {
  const holdings = replayTokenHoldingsAt(tradesAsc, deadline);
  let sum = 0;
  for (const [sid, tok] of holdings) {
    if (tok <= 1e-12) {
      continue;
    }
    const px = lastTradePriceBefore(
      tradesAsc,
      sid,
      deadline,
      currentTokenPriceByStartup.get(sid) ?? 0
    );
    sum += tok * px;
  }
  return sum;
}

export type WalletTokenPerformanceSeries = {
  readonly sampleTimesIso: string[];
  readonly valuesBrl: number[];
  readonly changePctFirstLast: number | null;
  readonly minBrl: number | null;
  readonly maxBrl: number | null;
  readonly trendLabel: string;
};

function percentChangeFirstLast(values: readonly number[]): number | null {
  if (values.length < 2) {
    return null;
  }
  const a = values[0];
  const b = values[values.length - 1];
  if (a === undefined || b === undefined) {
    return null;
  }
  if (!Number.isFinite(a) || !Number.isFinite(b)) {
    return null;
  }
  if (Math.abs(a) < 1e-9) {
    return null;
  }
  const pct = ((b - a) / a) * 100;
  return Number.isFinite(pct) ? pct : null;
}

function trendLabelFromPct(pct: number | null): string {
  if (pct == null) {
    return "Variação indisponível no período.";
  }
  const s = pct.toFixed(1).replace(".", ",");
  if (pct > 0.05) {
    return `Tendência de alta (~+${s}% no período).`;
  }
  if (pct < -0.05) {
    return `Tendência de queda (~${s}% no período).`;
  }
  return `Oscilação ligeira (~${s}% no período).`;
}

/**
 * Constrói a série usada no gráfico “valorização dos tokens” + estatísticas simples.
 */
export function buildWalletTokenPerformanceSeries(
  period: WalletPerformancePeriod,
  now: Date,
  tradesAsc: readonly LedgerTradeRow[],
  currentTokenPriceByStartup: ReadonlyMap<string, number>,
  sampleCount = 7
): WalletTokenPerformanceSeries {
  const inicio = periodWindowStartUtc(period, now);
  const instants = sampleInstantsUtc(inicio, now, sampleCount);
  const values = instants.map((t) =>
    portfolioTokenMarketValueBrl(tradesAsc, t, currentTokenPriceByStartup)
  );
  const pct = percentChangeFirstLast(values);
  let minB: number | null = null;
  let maxB: number | null = null;
  for (const v of values) {
    if (!Number.isFinite(v)) {
      continue;
    }
    minB = minB == null ? v : Math.min(minB, v);
    maxB = maxB == null ? v : Math.max(maxB, v);
  }
  return {
    sampleTimesIso: instants.map((d) => d.toISOString()),
    valuesBrl: values,
    changePctFirstLast: pct,
    minBrl: minB,
    maxBrl: maxB,
    trendLabel: trendLabelFromPct(pct),
  };
}
