/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Callable HTTPS: `getStartupMarketStats`
 *
 * Calcula estatísticas de **cotação de mercado** a partir de:
 * 1. **Preferência:** `historico_cotacao_sim` — pontos gerados pelo job agendado
 *    [tickStartupMarketPrices] (variação simulada do `preco_token`).
 * 2. **Fallback:** `grafico_valuation.diario` escalado para BRL e ancorado em `preco_token`
 *    (comportamento anterior, útil antes de existir histórico ou sem pontos suficientes).
 *
 * Entrada: `startupId` (documento em `startups/{id}`).
 *
 * Saída: `{ data: { tokenPriceBrl, changePct24h, min24hBrl, max24hBrl, seriesDiario, footnote } }`
 */

import {
  getFirestore,
  type DocumentData,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";

import {requireAuthenticatedUser} from "../../startups/shared/auth.js";
import {
  REGION,
  STARTUPS_COLLECTION,
  STARTUP_FIELD_HISTORICO_COTACAO_SIM,
} from "../shared/constants.js";
import {parseHistoricoCotacaoSimArray} from "../shared/marketHistoricoParse.js";
import {readRequiredStartupTokenPriceBrl} from "../shared/validation.js";
import {
  cotacaoBrlFromValuationSeries,
  parseGraficoValuationDiario,
  statsLastWindowHours,
} from "../shared/startupMarketMath.js";

function clipId(raw: unknown): string {
  if (typeof raw !== "string") {
    return "";
  }
  return raw.trim().slice(0, 400);
}

export const getStartupMarketStats = onCall({region: REGION}, async (request) => {
  requireAuthenticatedUser(request);
  const startupId = clipId(request.data?.startupId);
  if (!startupId) {
    throw new HttpsError("invalid-argument", "Informe startupId.");
  }

  const db = getFirestore();
  const snap = await db.collection(STARTUPS_COLLECTION).doc(startupId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Startup não encontrada.");
  }

  const data = snap.data() as DocumentData | undefined;
  const precoAtual = readRequiredStartupTokenPriceBrl(data);

  const historicoPts = parseHistoricoCotacaoSimArray(data?.[STARTUP_FIELD_HISTORICO_COTACAO_SIM]);

  if (historicoPts.length >= 2) {
    const stats = statsLastWindowHours(historicoPts, 24);
    const seriesDiario = historicoPts.map((p) => ({
      tIso: p.t.toISOString(),
      priceBrl: p.priceBrl,
    }));
    const footnote =
      "Cotação simulada: pontos do campo historico_cotacao_sim (Scheduler atualiza preco_token). " +
      "Min/máx 24h = janela móvel de 24h até ao último instante da série.";
    return {
      data: {
        startupId,
        tokenPriceBrl: precoAtual,
        changePct24h: stats.changePct24h,
        min24hBrl: stats.minBrl,
        max24hBrl: stats.maxBrl,
        seriesDiario,
        footnote,
      },
    };
  }

  const grafico = data?.["grafico_valuation"];
  const parsed = parseGraficoValuationDiario(grafico);

  const footnoteFallback =
    "Fallback: série proporcional a grafico_valuation.diario ancorada em preco_token. " +
    "Após o job agendado gravar historico_cotacao_sim, o app pode mostrar variação mais realista.";

  if (!parsed || parsed.length < 2) {
    return {
      data: {
        startupId,
        tokenPriceBrl: precoAtual,
        changePct24h: null as number | null,
        min24hBrl: null as number | null,
        max24hBrl: null as number | null,
        seriesDiario: [] as { tIso: string; priceBrl: number }[],
        footnote:
          footnoteFallback +
          " Sem pontos suficientes no histórico simulado nem em grafico_valuation.diario.",
      },
    };
  }

  const vals = parsed.map((p) => p.v);
  const times = parsed.map((p) => p.t);
  const points = cotacaoBrlFromValuationSeries(vals, times, precoAtual);
  const stats = statsLastWindowHours(points, 24);

  const seriesDiario = points.map((p) => ({
    tIso: p.t.toISOString(),
    priceBrl: p.priceBrl,
  }));

  return {
    data: {
      startupId,
      tokenPriceBrl: precoAtual,
      changePct24h: stats.changePct24h,
      min24hBrl: stats.minBrl,
      max24hBrl: stats.maxBrl,
      seriesDiario,
      footnote: footnoteFallback + " Variação 24h usa janela móvel até ao último ponto.",
    },
  };
});
