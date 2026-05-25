// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Matemática pura de escrow (saldo/tokens disponíveis para novas ordens).

import type {DocumentData} from "firebase-admin/firestore";

import {
  POSITION_FIELD_TOKENS_LOCKED,
  WALLET_FIELD_BRL_LOCKED,
} from "./constants.js";

/** Lê saldo BRL disponível descontando o escrow de ordens de compra. */
export function readAvailableBrl(walletData: DocumentData | undefined): number {
  const balance =
    typeof walletData?.brlBalance === "number" ? walletData.brlBalance : 0;
  const locked =
    typeof walletData?.[WALLET_FIELD_BRL_LOCKED] === "number"
      ? (walletData[WALLET_FIELD_BRL_LOCKED] as number)
      : 0;
  return Math.max(0, balance - locked);
}

/** Lê tokens disponíveis descontando o escrow de ordens de venda. */
export function readAvailableTokens(posData: DocumentData | undefined): number {
  const held =
    typeof posData?.tokensHeld === "number" ? posData.tokensHeld : 0;
  const locked =
    typeof posData?.[POSITION_FIELD_TOKENS_LOCKED] === "number"
      ? (posData[POSITION_FIELD_TOKENS_LOCKED] as number)
      : 0;
  return Math.max(0, held - locked);
}

/** Valor total bloqueado em BRL para uma ordem de compra. */
export function orderBuyLockBrl(quantity: number, pricePerToken: number): number {
  return quantity * pricePerToken;
}

/** Lê escrow BRL já reservado na carteira (default 0). */
export function readBrlLocked(walletData: DocumentData | undefined): number {
  const locked = walletData?.[WALLET_FIELD_BRL_LOCKED];
  return typeof locked === "number" && Number.isFinite(locked) ? locked : 0;
}

/** Lê escrow de tokens na posição (default 0). */
export function readTokensLocked(posData: DocumentData | undefined): number {
  const locked = posData?.[POSITION_FIELD_TOKENS_LOCKED];
  return typeof locked === "number" && Number.isFinite(locked) ? locked : 0;
}

/** Lê tokensHeld na posição (default 0). */
export function readTokensHeld(posData: DocumentData | undefined): number {
  const held = posData?.tokensHeld;
  return typeof held === "number" && Number.isFinite(held) ? held : 0;
}

/** Lê brlBalance na carteira (default 0). */
export function readBrlBalance(walletData: DocumentData | undefined): number {
  const balance = walletData?.brlBalance;
  return typeof balance === "number" && Number.isFinite(balance) ? balance : 0;
}
