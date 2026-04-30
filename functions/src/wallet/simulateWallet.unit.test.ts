import test from "node:test";
import assert from "node:assert/strict";

import {__test__} from "./simulateWallet.js";

test("readRequiredStartupTokenPriceBrl reads numeric price", () => {
  const p = __test__.readRequiredStartupTokenPriceBrl({preco_token: 12.34});
  assert.equal(p, 12.34);
});

test("readRequiredStartupTokenPriceBrl accepts numeric strings", () => {
  const p = __test__.readRequiredStartupTokenPriceBrl({preco_token: "9.5"});
  assert.equal(p, 9.5);
});

test("readRequiredStartupTokenPriceBrl throws on missing/invalid", () => {
  assert.throws(() => __test__.readRequiredStartupTokenPriceBrl({}), /Cotação do token/);
  assert.throws(
    () => __test__.readRequiredStartupTokenPriceBrl({preco_token: -1}),
    /Cotação do token/
  );
});

test("assertAmountMatchesTrade validates implied amount within epsilon", () => {
  assert.doesNotThrow(() => __test__.assertAmountMatchesTrade(10.0, 2, 5.0));
  assert.doesNotThrow(() => __test__.assertAmountMatchesTrade(10.05, 2, 5.0)); // within 0.06
  assert.throws(
    () => __test__.assertAmountMatchesTrade(10.2, 2, 5.0),
    /não conferem/
  );
});

test("clip trims and limits length", () => {
  assert.equal(__test__.clip("  abc  ", 10), "abc");
  assert.equal(__test__.clip("abcdefgh", 4), "abcd");
  assert.equal(__test__.clip(null, 10), "");
});

