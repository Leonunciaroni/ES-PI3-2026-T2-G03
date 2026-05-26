/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 */

import test from "node:test";
import assert from "node:assert/strict";

import {
  computeSellPositionUpdate,
  mergeBuyPosition,
} from "./positionTradeMath.js";

test("mergeBuyPosition acumula tokens e custo", () => {
  const a = mergeBuyPosition(undefined, 2, 10);
  assert.deepEqual(a, {tokensHeld: 2, costBasisBrl: 10});
  const b = mergeBuyPosition(a, 1, 5);
  assert.deepEqual(b, {tokensHeld: 3, costBasisBrl: 15});
});

test("computeSellPositionUpdate proporcional ao custo", () => {
  const up = computeSellPositionUpdate(
    {tokensHeld: 10, costBasisBrl: 100},
    2
  );
  assert.equal(up.ok, true);
  if (!up.ok) return;
  assert.equal(up.deletePosition, false);
  assert.equal(up.tokensHeld, 8);
  assert.ok(Math.abs(up.costBasisBrl - 80) < 1e-9);
});

test("computeSellPositionUpdate apaga posição ao zerar tokens", () => {
  const up = computeSellPositionUpdate(
    {tokensHeld: 5, costBasisBrl: 50},
    5
  );
  assert.equal(up.ok, true);
  if (!up.ok) return;
  assert.equal(up.deletePosition, true);
});

test("computeSellPositionUpdate falha sem tokens suficientes", () => {
  const up = computeSellPositionUpdate(
    {tokensHeld: 1, costBasisBrl: 10},
    2
  );
  assert.equal(up.ok, false);
});
