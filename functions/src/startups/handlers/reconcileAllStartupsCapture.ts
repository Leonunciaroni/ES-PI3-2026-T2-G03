/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Callable reconcileAllStartupsCapture — executa a mesma reconciliação que
 * reconcileStartupCapture, mas para **cada** documento na coleção startups.
 *
 * Use **uma vez** após deploy (ou quando existirem negócios antigos no ledger
 * antes do contador automático): assim investimentos passados passam a aparecer
 * nas barras de captação sem precisar de novo aporte.
 *
 * Pedido: usuário autenticado; corpo vazio {}.
 */
import {getFirestore} from "firebase-admin/firestore";
import {onCall} from "firebase-functions/https";

import {requireAuthenticatedUser} from "../shared/auth.js";
import {reconcileOneStartupDocument} from "../shared/reconcileStartupCaptureCore.js";
import {STARTUPS_COLLECTION} from "../../wallet/shared/constants.js";

export const reconcileAllStartupsCapture = onCall({region: "us-central1"}, async (request) => {
  requireAuthenticatedUser(request);

  const db = getFirestore();
  const snap = await db.collection(STARTUPS_COLLECTION).get();

  const results: Array<{
    startupId: string;
    valorCaptadoAcumuladoBrl: number;
    progressoCaptacao: number;
  }> = [];

  for (const doc of snap.docs) {
    const one = await reconcileOneStartupDocument(db, doc.id);
    if (one != null) {
      results.push({
        startupId: one.startupId,
        valorCaptadoAcumuladoBrl: one.valorCaptadoAcumuladoBrl,
        progressoCaptacao: one.progressoCaptacao,
      });
    }
  }

  return {
    ok: true,
    totalStartups: snap.docs.length,
    results,
  };
});
