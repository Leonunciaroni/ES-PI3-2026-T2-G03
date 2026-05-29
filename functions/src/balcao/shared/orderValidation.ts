// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Validações de payload das ordens P2P.

import {HttpsError} from "firebase-functions/https";

import {MAX_OP_BRL} from "./constants.js";

/** Valida quantity como inteiro positivo. */
export function assertPositiveIntegerQuantity(raw: unknown, label = "quantity"): number {
  const n = Number(raw);
  if (!Number.isFinite(n) || !Number.isInteger(n) || n <= 0) {
    throw new HttpsError(
      "invalid-argument",
      `Informe uma quantidade de tokens válida (${label}).`
    );
  }
  return n;
}

/** Valida preço por token positivo e finito. */
export function assertPositivePrice(raw: unknown): number {
  const p = Number(raw);
  if (!Number.isFinite(p) || p <= 0) {
    throw new HttpsError("invalid-argument", "Informe um preço por token válido.");
  }
  return p;
}

/** Valida startupId não vazio. */
export function assertStartupId(raw: unknown): string {
  const id = typeof raw === "string" ? raw.trim() : "";
  if (!id) {
    throw new HttpsError("invalid-argument", "startupId obrigatório.");
  }
  if (id.length > 200) {
    throw new HttpsError("invalid-argument", "startupId inválido.");
  }
  return id;
}

/** Valida valor total da ordem de compra dentro dos limites. */
export function assertOrderTotalWithinLimits(totalBrl: number): void {
  if (!Number.isFinite(totalBrl) || totalBrl <= 0 || totalBrl > MAX_OP_BRL) {
    throw new HttpsError("invalid-argument", "Valor total da ordem fora dos limites.");
  }
}
