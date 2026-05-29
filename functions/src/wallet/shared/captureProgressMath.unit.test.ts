/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 */

import test from "node:test";
import assert from "node:assert/strict";

import {
  computeCaptureProgressFraction,
  readOptionalNonNegativeNumber,
} from "./captureProgressMath.js";

test("computeCaptureProgressFraction — metade da meta", () => {
  assert.equal(computeCaptureProgressFraction(5e6, 10e6), 0.5);
});

test("computeCaptureProgressFraction — limita a 1 quando captado > meta", () => {
  assert.equal(computeCaptureProgressFraction(12e6, 10e6), 1);
});

test("computeCaptureProgressFraction — zero se meta ausente ou zero", () => {
  assert.equal(computeCaptureProgressFraction(1, 0), 0);
  assert.equal(computeCaptureProgressFraction(1, -1), 0);
});

test("readOptionalNonNegativeNumber aceita string BR", () => {
  assert.equal(readOptionalNonNegativeNumber("1000000,5"), 1000000.5);
});
