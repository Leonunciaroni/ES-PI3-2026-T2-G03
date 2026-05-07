/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Lógica pública partilhada para calcular o próximo preço simulado do token (PI3).
 */

/**
 * Cálculo puro do próximo preço simulado — testável sem Firestore.
 */

import {MARKET_MAX_RELATIVE_STEP} from "./marketSimulationConfig.js";

/**
 * Gera o próximo preço em BRL a partir do anterior, com variação aleatória limitada.
 *
 * Regra:
 * - sorteia um factor em [-MARKET_MAX_RELATIVE_STEP, +MARKET_MAX_RELATIVE_STEP];
 * - multiplica o preço anterior por (1 + factor);
 * - redondeia e impõe um piso mínimo positivo.
 */
export function nextSimulatedTokenPriceBrl(
  previousBrl: number,
  random01: () => number = Math.random
): number {
  if (!Number.isFinite(previousBrl) || previousBrl <= 0) {
    return previousBrl;
  }
  const u = random01() * 2 - 1;
  const factor = 1 + u * MARKET_MAX_RELATIVE_STEP;
  let next = previousBrl * factor;
  if (!Number.isFinite(next) || next <= 0) {
    next = previousBrl;
  }
  next = Math.max(0.01, next);
  return Math.round(next * 10000) / 10000;
}
