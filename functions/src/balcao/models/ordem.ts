// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Tipos e enums do Order Book P2P (contrato Firestore).

import type {DocumentReference, Timestamp} from "firebase-admin/firestore";

/** Lado da ordem no livro. */
export enum TipoOrdem {
  Compra = "buy",
  Venda = "sell",
}

/** Estado da ordem. */
export enum StatusOrdem {
  Aberta = "open",
  Cancelada = "cancelled",
  Executada = "completed",
}

/** Documento de ordem gravado em `orders/{startupId}/sell|buy/{orderId}`. */
export interface Ordem {
  uid: string;
  displayName: string;
  startupId: string;
  startupName: string;
  tokenSigla: string;
  /** Sempre inteiro. */
  quantity: number;
  pricePerToken: number;
  /** Venda: +pricePerToken | Compra: -pricePerToken */
  sortKey: number;
  status: StatusOrdem;
  createdAt: Timestamp;
}

/** Dados mínimos de ordem para o match engine. */
export type OrdemMatchCandidate = {
  id: string;
  ref: DocumentReference;
  uid: string;
  quantity: number;
  pricePerToken: number;
  createdAt: Timestamp | undefined;
  startupName: string;
  tokenSigla: string;
};
