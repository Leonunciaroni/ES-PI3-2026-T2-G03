// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Sincroniza espelho de ordens abertas para ordens já existentes no Firestore.

import {onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

import {
  purgeForeignOpenOrderIndex,
  upsertUserOpenOrderIndex,
} from "../repositories/userOrderIndex.js";
import {requireAuthenticatedUser} from "../shared/auth.js";
import {
  ORDER_FIELD_STATUS,
  ORDER_FIELD_UID,
  REGION,
} from "../shared/constants.js";
import {db} from "../shared/firebase.js";
import {StatusOrdem, TipoOrdem} from "../types/index.js";

/**
 * Repopula `users/{uid}/balcao_ordens_abertas` a partir das ordens abertas
 * do usuário autenticado e remove entradas que não lhe pertencem.
 */
export const backfillMyOpenOrders = onCall({region: REGION}, async (request) => {
  const user = requireAuthenticatedUser(request);
  const uid = user.uid;

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
