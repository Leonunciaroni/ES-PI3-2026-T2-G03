// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Espelho das ordens abertas do utilizador para listagem no app (sem collection group).

import {FieldValue, getFirestore, type DocumentReference, type Timestamp} from "firebase-admin/firestore";

import {StatusOrdem, TipoOrdem} from "../models/ordem.js";
import {
  ORDER_FIELD_CREATED_AT,
  ORDER_FIELD_DISPLAY_NAME,
  ORDER_FIELD_PRICE,
  ORDER_FIELD_QUANTITY,
  ORDER_FIELD_STARTUP_ID,
  ORDER_FIELD_STARTUP_NAME,
  ORDER_FIELD_STATUS,
  ORDER_FIELD_TOKEN_SIGLA,
  ORDER_FIELD_UID,
  USERS_COLLECTION,
} from "./constants.js";

/** Subcoleção em `users/{uid}` — só ordens abertas do dono. */
export const USER_OPEN_ORDERS_SUBCOL = "balcao_ordens_abertas";

type OrderSide = TipoOrdem.Compra | TipoOrdem.Venda;

function userOpenOrderRef(ownerUid: string, tipo: OrderSide, orderId: string) {
  const db = getFirestore();
  const docId = `${tipo}_${orderId}`;
  return db
    .collection(USERS_COLLECTION)
    .doc(ownerUid)
    .collection(USER_OPEN_ORDERS_SUBCOL)
    .doc(docId);
}

function readOwnerUid(data: Record<string, unknown>): string {
  return String(data[ORDER_FIELD_UID] ?? "").trim();
}

/** Grava/atualiza espelho na subcoleção do **dono** (`data.uid`). */
export async function upsertUserOpenOrderIndex(
  tipo: OrderSide,
  orderId: string,
  data: Record<string, unknown>
): Promise<void> {
  const ownerUid = readOwnerUid(data);
  if (!ownerUid) return;

  if (String(data[ORDER_FIELD_STATUS] ?? "") !== StatusOrdem.Aberta) {
    await removeUserOpenOrderIndex(ownerUid, tipo, orderId);
    return;
  }

  await userOpenOrderRef(ownerUid, tipo, orderId).set(
    {
      orderId,
      tipo,
      uid: ownerUid,
      displayName: String(data[ORDER_FIELD_DISPLAY_NAME] ?? ""),
      startupId: String(data[ORDER_FIELD_STARTUP_ID] ?? ""),
      startupName: String(data[ORDER_FIELD_STARTUP_NAME] ?? ""),
      tokenSigla: String(data[ORDER_FIELD_TOKEN_SIGLA] ?? ""),
      quantity: Number(data[ORDER_FIELD_QUANTITY]),
      pricePerToken: Number(data[ORDER_FIELD_PRICE]),
      status: StatusOrdem.Aberta,
      createdAt: data[ORDER_FIELD_CREATED_AT] ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true}
  );
}

/** Remove espelho ao cancelar, executar ou fechar ordem. */
export async function removeUserOpenOrderIndex(
  ownerUid: string,
  tipo: OrderSide,
  orderId: string
): Promise<void> {
  await userOpenOrderRef(ownerUid, tipo, orderId).delete();
}

/** Remove documentos espelho que não pertencem ao utilizador (dados legados). */
export async function purgeForeignOpenOrderIndex(uid: string): Promise<number> {
  const db = getFirestore();
  const snap = await db
    .collection(USERS_COLLECTION)
    .doc(uid)
    .collection(USER_OPEN_ORDERS_SUBCOL)
    .get();

  let removed = 0;
  for (const doc of snap.docs) {
    const owner = String(doc.data().uid ?? "").trim();
    if (owner !== uid) {
      await doc.ref.delete();
      removed++;
    }
  }
  return removed;
}

/** Atualiza quantidade no espelho após match parcial. */
export async function patchUserOpenOrderQuantity(
  ownerUid: string,
  tipo: OrderSide,
  orderId: string,
  quantity: number
): Promise<void> {
  if (quantity <= 0) {
    await removeUserOpenOrderIndex(ownerUid, tipo, orderId);
    return;
  }
  await userOpenOrderRef(ownerUid, tipo, orderId).set(
    {
      quantity,
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true}
  );
}

export type UserOpenOrderIndexDoc = {
  orderId: string;
  tipo: string;
  uid: string;
  displayName: string;
  startupId: string;
  startupName: string;
  tokenSigla: string;
  quantity: number;
  pricePerToken: number;
  status: string;
  createdAt?: Timestamp;
};

/** Sincroniza espelho a partir do documento canónico da ordem. */
export async function syncOpenOrderIndexFromRef(
  orderRef: DocumentReference,
  tipo: OrderSide
): Promise<void> {
  const snap = await orderRef.get();
  if (!snap.exists) return;
  const data = snap.data() ?? {};
  if (!readOwnerUid(data)) return;
  await upsertUserOpenOrderIndex(tipo, snap.id, data);
}
