// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Sincroniza espelho de ordens abertas para ordens já existentes no Firestore.

import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

import {StatusOrdem, TipoOrdem} from "./models/ordem.js";
import {
  ORDER_FIELD_STATUS,
  ORDER_FIELD_UID,
  REGION,
} from "./shared/constants.js";
import {
  purgeForeignOpenOrderIndex,
  upsertUserOpenOrderIndex,
} from "./shared/userOrderIndex.js";

/**
 * Repopula `users/{uid}/balcao_ordens_abertas` a partir das ordens abertas
 * do usuário autenticado e remove entradas que não lhe pertencem.
 */
export const backfillMyOpenOrders = onCall({region: REGION}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Precisa iniciar sessão.");
  }
  const uid = request.auth.uid;
  const db = getFirestore();

  const removed = await purgeForeignOpenOrderIndex(uid);

  const [sellSnap, buySnap] = await Promise.all([
    db
      .collectionGroup("sell")
      .where(ORDER_FIELD_UID, "==", uid)
      .where(ORDER_FIELD_STATUS, "==", StatusOrdem.Aberta)
      .get(),
    db
      .collectionGroup("buy")
      .where(ORDER_FIELD_UID, "==", uid)
      .where(ORDER_FIELD_STATUS, "==", StatusOrdem.Aberta)
      .get(),
  ]);

  let synced = 0;
  for (const doc of sellSnap.docs) {
    const owner = String(doc.data()[ORDER_FIELD_UID] ?? "").trim();
    if (owner !== uid) continue;
    await upsertUserOpenOrderIndex(TipoOrdem.Venda, doc.id, doc.data());
    synced++;
  }
  for (const doc of buySnap.docs) {
    const owner = String(doc.data()[ORDER_FIELD_UID] ?? "").trim();
    if (owner !== uid) continue;
    await upsertUserOpenOrderIndex(TipoOrdem.Compra, doc.id, doc.data());
    synced++;
  }

  logger.info("backfillMyOpenOrders", {uid, synced, removed});
  return {ok: true, synced, removed};
});
