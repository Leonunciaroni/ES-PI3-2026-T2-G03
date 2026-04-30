/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Constantes do módulo Wallet (carteira simulada).
 *
 * Objetivo: centralizar nomes de coleções/campos e limites num único lugar para:
 * - evitar “strings mágicas” espalhadas;
 * - manter o backend (Functions) alinhado ao app Flutter;
 * - facilitar manutenção quando o contrato Firestore evoluir.
 */

/** Região das Cloud Functions callable (alinhada ao cliente Flutter). */
export const REGION = "us-central1";

/** Raiz da carteira simulada no Firestore. */
export const ROOT = "sim_wallet";

/** Coleção de startups (cotação oficial por documento). */
export const STARTUPS_COLLECTION = "startups";

/** Campo de preço unitário do token em BRL (contrato alinhado ao app). */
export const STARTUP_FIELD_TOKEN_PRICE = "preco_token";

/** Limite superior de valor por operação simulada (BRL). */
export const MAX_OP_BRL = 50_000_000;

/**
 * Tolerância BRL entre valor declarado e tokens × preço.
 *
 * Ex.: por arredondamento de centavos no cliente, \(tokens * preço\) pode divergir
 * alguns centavos do `amountBrl`. Este EPSILON evita rejeitar operações válidas.
 */
export const EPSILON_BRL = 0.06;
