/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Tipos partilhados do módulo Wallet.
 *
 * Mantemos este arquivo pequeno de propósito: é um “contrato” para o que é
 * gravado no ledger (`op`). Ao crescer, pode ganhar mais types/interfaces.
 */

/** Operações gravadas no ledger da carteira simulada. */
export type SimWalletLedgerOp =
  | "credit_pix_simulated"
  | "trade_buy"
  | "trade_sell";
