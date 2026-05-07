/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 */

import {Timestamp} from "firebase-admin/firestore";
import test from "node:test";
import assert from "node:assert/strict";

import {
  cotacaoBrlFromValuationSeries,
  interpolatePriceBrl,
  parseGraficoValuationDiario,
  statsLastWindowHours,
} from "./startupMarketMath.js";

test("cotacaoBrlFromValuationSeries anchors last point to precoAtual", () => {
  const t = [
    new Date("2026-04-01T10:00:00Z"),
    new Date("2026-04-02T10:00:00Z"),
  ];
  const v = [10, 20];
  const pts = cotacaoBrlFromValuationSeries(v, t, 15);
  assert.equal(pts.length, 2);
  assert.equal(pts[1]?.priceBrl, 15);
  assert.equal(pts[0]?.priceBrl, 7.5);
});

test("statsLastWindowHours returns change for synthetic series", () => {
  const base = new Date("2026-04-10T12:00:00Z");
  const series = [
    {t: new Date(base.getTime() - 48 * 3600 * 1000), priceBrl: 100},
    {t: new Date(base.getTime() - 24 * 3600 * 1000), priceBrl: 110},
    {t: base, priceBrl: 121},
  ];
  const st = statsLastWindowHours(series, 24);
  assert.ok(st.changePct24h != null);
  assert.ok(Math.abs((st.changePct24h ?? 0) - 10) < 0.01);
});

test("interpolatePriceBrl returns midpoint", () => {
  const a = new Date("2026-01-01T00:00:00Z");
  const b = new Date("2026-01-03T00:00:00Z");
  const mid = new Date("2026-01-02T00:00:00Z");
  const series = [
    {t: a, priceBrl: 0},
    {t: b, priceBrl: 100},
  ];
  const p = interpolatePriceBrl(series, mid);
  assert.ok(p != null && Math.abs(p - 50) < 1e-9);
});

test("parseGraficoValuationDiario aceita Timestamp do Firestore em t", () => {
  const t1 = Timestamp.fromDate(new Date("2026-04-01T10:00:00.000Z"));
  const t2 = Timestamp.fromDate(new Date("2026-04-03T10:00:00.000Z"));
  const parsed = parseGraficoValuationDiario({
    diario: [
      {t: t1, v: 10},
      {t: t2, v: 20},
    ],
  });
  assert.ok(parsed != null && parsed.length === 2);
  assert.equal(parsed![0]?.v, 10);
  assert.equal(parsed![1]?.v, 20);
});
