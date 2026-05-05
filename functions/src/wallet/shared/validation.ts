/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Validações e sanitização do módulo Wallet.
 *
 * Nota didática:
 * - validações “baratas” (tipos/limites) evitam gravar dados inválidos;
 * - sanitização (`clip`) reduz risco de poluição de logs / documentos auditáveis;
 * - estas funções são puras e fáceis de testar (ver `handlers/simulateWallet.unit.test.ts`).
 */

import type {DocumentData} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";

import {EPSILON_BRL, STARTUP_FIELD_TOKEN_PRICE} from "./constants.js";

/**
 * Valida total ≈ tokens * preço (tolerância de arredondamento).
 *
 * Por que existe:
 * - o cliente envia `amountBrl` e `tokens`;
 * - o backend calcula o preço oficial e confere se os números batem;
 * - se não bater, a operação é rejeitada com `failed-precondition`.
 */
export function assertAmountMatchesTrade(
  amountBrl: number,
  tokens: number,
  tokenPriceBrl: number
): void {
  if (tokens <= 0 || !Number.isFinite(tokens)) {
    throw new HttpsError("invalid-argument", "Informe uma quantidade de tokens válida.");
  }
  if (tokenPriceBrl <= 0 || !Number.isFinite(tokenPriceBrl)) {
    throw new HttpsError("invalid-argument", "Preço por token inválido.");
  }
  const implied = tokens * tokenPriceBrl;
  if (Math.abs(amountBrl - implied) > EPSILON_BRL) {
    throw new HttpsError(
      "failed-precondition",
      "Valor em reais e quantidade de tokens não conferem com a cotação."
    );
  }
}

/**
 * Recorta strings vindas da app antes de gravar nos documentos auditáveis.
 *
 * Exemplo: `headline`, `startupName`, `tokenSigla`.
 * - remove espaços nas pontas;
 * - limita tamanho para evitar valores gigantes em Firestore.
 */
export function clip(s: unknown, max: number): string {
  if (typeof s !== "string") {
    return "";
  }
  const t = s.trim();
  return t.length > max ? t.slice(0, max) : t;
}

/**
 * Lê [STARTUP_FIELD_TOKEN_PRICE] do documento da startup ou falha com [HttpsError].
 *
 * Importante: a cotação é fonte de verdade do backend. Assim evitamos confiar
 * no preço enviado pelo cliente (que poderia ser manipulado).
 */
export function readRequiredStartupTokenPriceBrl(
  startupSnapData: DocumentData | undefined
): number {
  const raw = startupSnapData?.[STARTUP_FIELD_TOKEN_PRICE];
  const p = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(p) || p <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "Cotação do token indisponível para esta startup."
    );
  }
  return p;
}
