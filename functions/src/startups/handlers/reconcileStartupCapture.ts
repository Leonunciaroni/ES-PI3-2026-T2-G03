/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Callable reconcileStartupCapture — recalcula valor_captado_acumulado_brl e
 * progresso_captacao no documento startups/{id} somando todas as linhas do
 * extrato simulado (subcoleção ledger em cada sim_wallet) dessa startup.
 *
 * Porquê existe:
 * - O fluxo normal já atualiza estes campos em cada compra/venda (simulateWallet);
 * - esta função serve para corrigir divergências ou depois de dados antigos sem contador.
 *
 * Investimento total = soma de amountBrl em trade_buy menos trade_sell,
 * para todos os utilizadores (cada carteira tem o seu ledger).
 */
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";

import {requireAuthenticatedUser} from "../shared/auth.js";
import {normalizeString} from "../shared/validation.js";
import {reconcileOneStartupDocument} from "../shared/reconcileStartupCaptureCore.js";

export const reconcileStartupCapture = onCall({region: "us-central1"}, async (request) => {
  requireAuthenticatedUser(request);

  const startupId = normalizeString(request.data?.startupId);
  if (!startupId) {
    throw new HttpsError(
      "invalid-argument",
      "Informe startupId para reconciliar a captação."
    );
  }

  const db = getFirestore();
  const out = await reconcileOneStartupDocument(db, startupId);
  if (out == null) {
    throw new HttpsError("not-found", "Startup não encontrada.");
  }

  return {
    ok: true,
    startupId: out.startupId,
    valorCaptadoAcumuladoBrl: out.valorCaptadoAcumuladoBrl,
    captacaoEsperadaBrl: out.captacaoEsperadaBrl,
    progressoCaptacao: out.progressoCaptacao,
  };
});
