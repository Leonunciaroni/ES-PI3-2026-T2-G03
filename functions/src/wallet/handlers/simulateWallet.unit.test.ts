// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
//
// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Testes unitários do módulo Wallet (pure functions).
// Objetivo:
// - garantir que validações e sanitização funcionam;
// - manter testes rápidos (não dependem do emulador nem do Firestore real).
// Execução: `cd functions && npm test`

import test from "node:test";
import assert from "node:assert/strict";

import {
  assertAmountMatchesTrade,
  assertPositiveIntegerTokens,
  clip,
  readRequiredStartupTokenPriceBrl,
} from "../shared/validation.js";

test("readRequiredStartupTokenPriceBrl reads numeric price", () => {
  const p = readRequiredStartupTokenPriceBrl({preco_token: 12.34});
  assert.equal(p, 12.34);
});

test("readRequiredStartupTokenPriceBrl accepts numeric strings", () => {
  const p = readRequiredStartupTokenPriceBrl({preco_token: "9.5"});
  assert.equal(p, 9.5);
});

test("readRequiredStartupTokenPriceBrl throws on missing/invalid", () => {
  assert.throws(() => readRequiredStartupTokenPriceBrl({}), /Cotação do token/);
  assert.throws(
    () => readRequiredStartupTokenPriceBrl({preco_token: -1}),
    /Cotação do token/
  );
});

test("assertPositiveIntegerTokens accepts positive integers", () => {
  assert.equal(assertPositiveIntegerTokens(2), 2);
  assert.equal(assertPositiveIntegerTokens("3"), 3);
});

test("assertPositiveIntegerTokens rejects fractions and non-positive", () => {
  assert.throws(
    () => assertPositiveIntegerTokens(2.466),
    /quantidade de tokens/
  );
  assert.throws(() => assertPositiveIntegerTokens(0), /quantidade de tokens/);
  assert.throws(() => assertPositiveIntegerTokens(-1), /quantidade de tokens/);
});

test("assertAmountMatchesTrade validates implied amount within epsilon", () => {
  assert.doesNotThrow(() => assertAmountMatchesTrade(10.0, 2, 5.0));
  assert.doesNotThrow(() => assertAmountMatchesTrade(10.05, 2, 5.0));
  assert.throws(
    () => assertAmountMatchesTrade(10.2, 2, 5.0),
    /não conferem/
  );
});

test("assertAmountMatchesTrade rejects fractional tokens", () => {
  assert.throws(
    () => assertAmountMatchesTrade(12.34, 2.466, 5.0),
    /quantidade de tokens/
  );
});

test("clip trims and limits length", () => {
  assert.equal(clip("  abc  ", 10), "abc");
  assert.equal(clip("abcdefgh", 4), "abcd");
  assert.equal(clip(null, 10), "");
});
