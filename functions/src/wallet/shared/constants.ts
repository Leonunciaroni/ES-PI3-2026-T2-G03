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
export const USERS_COLLECTION = "users";

/** Campo de preço unitário do token em BRL (contrato alinhado ao app). */
export const STARTUP_FIELD_TOKEN_PRICE = "preco_token";

/** Meta de captação da rodada (BRL) — mesmo nome que `kFieldCaptacaoEsperada` no Flutter. */
export const STARTUP_FIELD_CAPTACAO_ESPERADA = "captacao_esperada";

/**
 * Total líquido “captado” em BRL (soma das compras − vendas no balcão simulado).
 * Atualizado pelo servidor em cada `trade_buy` / `trade_sell` em [simulateWallet].
 */
export const STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO = "valor_captado_acumulado_brl";

/** Fração 0..1 da meta; derivado de captado ÷ [STARTUP_FIELD_CAPTACAO_ESPERADA]. */
export const STARTUP_FIELD_PROGRESSO_CAPTACAO = "progresso_captacao";

/**
 * Histórico curto de cotações simuladas (Scheduler): array de `{ t, p }`.
 * Usado por `getStartupMarketStats` para gráfico e min/máx 24h realistas.
 */
export const STARTUP_FIELD_HISTORICO_COTACAO_SIM = "historico_cotacao_sim";
export const STARTUP_FIELD_INVESTOR_UIDS = "investorUids";
export const USER_FIELD_INVESTOR_STARTUP_IDS = "investorStartupIds";

/** Limite superior de valor por operação simulada (BRL). */
export const MAX_OP_BRL = 50_000_000;

/**
 * Tolerância BRL entre valor declarado e tokens × preço.
 *
 * Ex.: por arredondamento de centavos no cliente, \(tokens * preço\) pode divergir
 * alguns centavos do `amountBrl`. Este EPSILON evita rejeitar operações válidas.
 */
export const EPSILON_BRL = 0.06;
