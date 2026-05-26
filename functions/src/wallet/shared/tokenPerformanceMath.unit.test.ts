/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Testes do módulo de valorização da carteira de tokens (funções puras).
 */

import test from "node:test";
import assert from "node:assert/strict";

import {
  buildWalletTokenPerformanceSeries,
  lastTradePriceBefore,
  parseWalletPeriod,
  portfolioTokenMarketValueBrl,
  replayTokenHoldingsAt,
  type LedgerTradeRow,
} from "./tokenPerformanceMath.js";

test("parseWalletPeriod accepts enum-style strings", () => {
  assert.equal(parseWalletPeriod("seisMeses"), "seisMeses");
  assert.equal(parseWalletPeriod("ytd"), "ytd");
  assert.equal(parseWalletPeriod("invalid"), null);
});

test("replayTokenHoldingsAt sums buys and subtracts sells", () => {
  const t0 = new Date("2026-01-10T12:00:00.000Z");
  const t1 = new Date("2026-01-11T12:00:00.000Z");
  const rows: LedgerTradeRow[] = [
    {
      at: t0,
      op: "trade_buy",
      startupId: "a",
      tokensQuantity: 10,
      tokenPriceBrl: 5,
    },
    {
      at: t1,
      op: "trade_sell",
      startupId: "a",
      tokensQuantity: 3,
      tokenPriceBrl: 6,
    },
  ];
  const h0 = replayTokenHoldingsAt(rows, t0);
  assert.equal(h0.get("a"), 10);
  const h1 = replayTokenHoldingsAt(rows, t1);
  assert.equal(h1.get("a"), 7);
});

test("portfolioTokenMarketValueBrl uses last trade price before deadline", () => {
  const t0 = new Date("2026-02-01T10:00:00.000Z");
  const rows: LedgerTradeRow[] = [
    {
      at: t0,
      op: "trade_buy",
      startupId: "s1",
      tokensQuantity: 4,
      tokenPriceBrl: 10,
    },
  ];
  const prices = new Map<string, number>([["s1", 99]]);
  const v = portfolioTokenMarketValueBrl(rows, t0, prices);
  assert.ok(Math.abs(v - 40) < 1e-9);
});

test("lastTradePriceBefore falls back to catalog price", () => {
  const t0 = new Date("2026-03-01T10:00:00.000Z");
  const rows: LedgerTradeRow[] = [
    {
      at: t0,
      op: "trade_buy",
      startupId: "x",
      tokensQuantity: 1,
      tokenPriceBrl: 12,
    },
  ];
  const p = lastTradePriceBefore(rows, "x", t0, 50);
  assert.equal(p, 12);
  const p2 = lastTradePriceBefore(rows, "x", new Date("2026-02-01T00:00:00.000Z"), 50);
  assert.equal(p2, 50);
});

test("buildWalletTokenPerformanceSeries produces non-empty series", () => {
  const now = new Date("2026-05-04T15:00:00.000Z");
  const rows: LedgerTradeRow[] = [
    {
      at: new Date("2026-05-01T12:00:00.000Z"),
      op: "trade_buy",
      startupId: "co",
      tokensQuantity: 2,
      tokenPriceBrl: 15,
    },
  ];
  const prices = new Map<string, number>([["co", 15]]);
  const s = buildWalletTokenPerformanceSeries("mensal", now, rows, prices, 5);
  assert.equal(s.valuesBrl.length, s.sampleTimesIso.length);
  assert.ok(s.valuesBrl.length >= 2);
});
