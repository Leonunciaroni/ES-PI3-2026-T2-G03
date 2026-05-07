/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Entrada do módulo Wallet: exporta handlers e types como o `auth/index.ts`.
 */

export {simulateWallet} from "./handlers/simulateWallet.js";
export {getWalletTokenPerformance} from "./handlers/getWalletTokenPerformance.js";
export {getStartupMarketStats} from "./handlers/getStartupMarketStats.js";
export {tickStartupMarketPrices} from "./handlers/tickStartupMarketPrices.js";
export type {SimWalletLedgerOp} from "./types/index.js";
