/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Configuração da **simulação de cotação** do token (PI3 — mercado fictício).
 */
/**
 * Configuração da **simulação de cotação** do token (PI3 — mercado fictício).
 *
 * Como ajustar sem editar a lógica (apenas deploy após alterar .env / variáveis):
 * - `MARKET_TICK_SCHEDULE`: expressão do Cloud Scheduler (ex.: `"every 20 minutes"`).
 * - `MARKET_MAX_PRICE_STEP_PCT`: passo máximo em percentagem por tick (ex.: `1.2` → ±1,2 %).
 */

/** Expressão cron do Scheduler Firebase (v2). Padrão: a cada 20 minutos. */
export const MARKET_TICK_SCHEDULE: string =
  process.env.MARKET_TICK_SCHEDULE?.trim() || "every 20 minutes";

/**
 * Número máximo de pontos guardados em `historico_cotacao_sim` por startup.
 * ~300 pontos × 20 min ≈ 4 dias de histórico denso.
 */
export const MARKET_HISTORY_MAX_POINTS = 300;

/**
 * Passo máximo **relativo** por tick: `novo = anterior * (1 + r)` com r uniforme em
 * [-MAX_RELATIVE_STEP, +MAX_RELATIVE_STEP].
 *
 * Override: env `MARKET_MAX_PRICE_STEP_PCT` em percentagem (ex.: `1.5` → 0,015).
 */
const envStepPct = process.env.MARKET_MAX_PRICE_STEP_PCT?.trim();
const parsedStep = envStepPct != null && envStepPct.length > 0 ? Number(envStepPct) : NaN;
export const MARKET_MAX_RELATIVE_STEP: number =
  Number.isFinite(parsedStep) && parsedStep > 0 && parsedStep <= 25
    ? parsedStep / 100
    : 0.012;
