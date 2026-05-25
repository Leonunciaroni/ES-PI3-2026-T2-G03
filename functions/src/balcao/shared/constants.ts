// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Constantes do módulo Balcão Order Book (coleções e campos escrow).

/** Coleção raiz do livro de ordens. */
export const ORDERS_COLLECTION = "orders";

/** Subcoleções de ordens por startup. */
export const ORDER_SUBCOL_SELL = "sell";
export const ORDER_SUBCOL_BUY = "buy";

/** BRL reservado em ordens de compra abertas (`sim_wallet/{uid}`). */
export const WALLET_FIELD_BRL_LOCKED = "brlLockedInOrders";

/** Tokens reservados em ordens de venda abertas (`positions/{startupId}`). */
export const POSITION_FIELD_TOKENS_LOCKED = "tokensLockedInOrders";

/** Campos de ordem no Firestore. */
export const ORDER_FIELD_UID = "uid";
export const ORDER_FIELD_DISPLAY_NAME = "displayName";
export const ORDER_FIELD_STARTUP_ID = "startupId";
export const ORDER_FIELD_STARTUP_NAME = "startupName";
export const ORDER_FIELD_TOKEN_SIGLA = "tokenSigla";
export const ORDER_FIELD_QUANTITY = "quantity";
export const ORDER_FIELD_PRICE = "pricePerToken";
export const ORDER_FIELD_SORT_KEY = "sortKey";
export const ORDER_FIELD_STATUS = "status";
export const ORDER_FIELD_CREATED_AT = "createdAt";

/** Reexporta região alinhada ao cliente Flutter. */
export {REGION} from "../../wallet/shared/constants.js";
export {
  ROOT as WALLET_ROOT,
  STARTUPS_COLLECTION,
  USERS_COLLECTION,
  STARTUP_FIELD_CAPTACAO_ESPERADA,
  STARTUP_FIELD_VALOR_CAPTADO_ACUMULADO,
  STARTUP_FIELD_PROGRESSO_CAPTACAO,
  STARTUP_FIELD_INVESTOR_UIDS,
  USER_FIELD_INVESTOR_STARTUP_IDS,
  MAX_OP_BRL,
} from "../../wallet/shared/constants.js";

/** Campo nome da startup no documento `startups`. */
export const STARTUP_FIELD_NAME = "nome_startup";

/** Campo sigla do token. */
export const STARTUP_FIELD_SIGLA = "sigla";
