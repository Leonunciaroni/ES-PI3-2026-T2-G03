/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Testes unitários da lógica de cálculo do próximo preço simulado do token (PI3).
 */

import test from "node:test";
import assert from "node:assert/strict";

import {nextSimulatedTokenPriceBrl} from "./marketPriceStep.js";

test("nextSimulatedTokenPriceBrl mantém positivo e perto do anterior com RNG fixo", () => {
  const prev = 10;
  const alwaysHalf = () => 0.5;
  const next = nextSimulatedTokenPriceBrl(prev, alwaysHalf);
  assert.ok(next > 0);
  assert.ok(Math.abs(next - prev) / prev < 0.02);
});

test("nextSimulatedTokenPriceBrl devolve anterior se inválido", () => {
  assert.equal(nextSimulatedTokenPriceBrl(-1), -1);
  assert.equal(nextSimulatedTokenPriceBrl(Number.NaN), Number.NaN);
});
