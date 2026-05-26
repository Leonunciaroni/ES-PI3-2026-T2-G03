// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726

import test from "node:test";
import assert from "node:assert/strict";

import {tokensHeldNeedsFloorMigration} from "./migrateFloorTokensHeld.js";

test("tokensHeldNeedsFloorMigration detecta frações", () => {
  assert.equal(tokensHeldNeedsFloorMigration(2.466), true);
  assert.equal(tokensHeldNeedsFloorMigration(0.5), true);
  assert.equal(tokensHeldNeedsFloorMigration(2), false);
  assert.equal(tokensHeldNeedsFloorMigration(0), false);
  assert.equal(tokensHeldNeedsFloorMigration(-1), false);
});
