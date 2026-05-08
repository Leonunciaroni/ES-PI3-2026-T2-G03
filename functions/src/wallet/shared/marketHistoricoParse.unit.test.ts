/**
 * Tests for parseHistoricoCotacaoSimArray (Firestore historico_cotacao_sim shape).
 */

import {Timestamp} from "firebase-admin/firestore";
import test from "node:test";
import assert from "node:assert/strict";

import {parseHistoricoCotacaoSimArray} from "./marketHistoricoParse.js";

test("parseHistoricoCotacaoSimArray: non-array returns empty", () => {
  assert.deepEqual(parseHistoricoCotacaoSimArray(undefined), []);
  assert.deepEqual(parseHistoricoCotacaoSimArray(null), []);
  assert.deepEqual(parseHistoricoCotacaoSimArray({}), []);
});

test("parseHistoricoCotacaoSimArray: accepts Timestamp and sorts by time", () => {
  const tLate = Timestamp.fromDate(new Date("2026-05-07T14:00:00.000Z"));
  const tEarly = Timestamp.fromDate(new Date("2026-05-07T12:00:00.000Z"));
  const raw = [
    {t: tLate, p: 20},
    {t: tEarly, p: 10},
  ];
  const pts = parseHistoricoCotacaoSimArray(raw);
  assert.equal(pts.length, 2);
  assert.equal(pts[0]?.priceBrl, 10);
  assert.equal(pts[1]?.priceBrl, 20);
  const first = pts[0];
  const second = pts[1];
  assert.ok(first && second && first.t.getTime() < second.t.getTime());
});

test("parseHistoricoCotacaoSimArray: accepts ISO strings and numeric string price", () => {
  const pts = parseHistoricoCotacaoSimArray([
    {t: "2026-01-01T10:00:00.000Z", p: "12,34"},
  ]);
  assert.equal(pts.length, 1);
  assert.ok(Math.abs((pts[0]?.priceBrl ?? 0) - 12.34) < 1e-9);
});

test("parseHistoricoCotacaoSimArray: skips invalid entries", () => {
  const pts = parseHistoricoCotacaoSimArray([
    null,
    {},
    {t: "not a date", p: 10},
    {t: "2026-04-01T10:00:00.000Z", p: -1},
    {t: "2026-04-01T10:00:00.000Z", p: 5},
  ]);
  assert.equal(pts.length, 1);
  assert.equal(pts[0]?.priceBrl, 5);
});
