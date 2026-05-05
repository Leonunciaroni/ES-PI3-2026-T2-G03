/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Callable HTTPS: `getStartupMarketStats`
 *
 * Calcula estatísticas de **cotação de mercado** (não confundir com P/L do investidor)
 * a partir de `preco_token` + `grafico_valuation.diario` no Firestore.
 *
 * Referência de escopo: §5.3 Balcão + §5.6 (simulação em Firestore; sem chain real).
 *
 * Entrada:
 * - `startupId`: string (documento em `startups/{id}`).
 *
 * Saída:
 * - `{ data: { tokenPriceBrl, changePct24h, min24hBrl, max24hBrl, seriesDiario, footnote } }`
 *   (`tokenPriceBrl` = `preco_token`, sempre presente quando a startup existe.)
 */

import {
  getFirestore,
  type DocumentData,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";

import {requireAuthenticatedUser} from "../../startups/shared/auth.js";
import {REGION, STARTUPS_COLLECTION} from "../shared/constants.js";
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

  const grafico = data?.["grafico_valuation"];
  const parsed = parseGraficoValuationDiario(grafico);

  const footnote =
    "Cotação simulada: série proporcional ao gráfico de valuation, ancorada em preco_token. " +
    "Variação 24h usa janela móvel até ao último ponto da série.";

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
          footnote +
          " Sem dados suficientes em grafico_valuation.diario — mostre apenas preco_token.",
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
      footnote,
    },
  };
});
