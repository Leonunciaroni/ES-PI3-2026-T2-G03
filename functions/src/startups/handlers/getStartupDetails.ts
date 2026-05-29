// Principal: Miguel Fernandes Costacurta - 25003110
// RA: 25003110
//
// Firebase Function (Callable) para **obter os detalhes de uma startup**.
//
// Escopo (PI3):
// - Obter os detalhes de uma startup
// - Validar o parametro id da startup
// - Validar o usuario autenticado
// - Validar o usuario e a startup

import {HttpsError, onCall} from "firebase-functions/https";
import {requireAuthenticatedUser} from "../shared/auth.js";
import {normalizeString} from "../shared/validation.js";
import {
  listQuestionsByVisibility,
  listStartupItems,
  userIsInvestor,
} from "../repositories/startupRepository.js";

export const getStartupDetails = onCall(
  {region: "us-central1"},
  async (request) => {
    const user = requireAuthenticatedUser(request);
    const startupId = normalizeString(request.data?.id);
    if (!startupId) {
      throw new HttpsError(
        "invalid-argument",
        "Informe o parametro id da startup."
      );
    }

    const startups = await listStartupItems({
      includeDetail: true,
      startupId,
    });
    const startup = startups[0];
    if (!startup) {
      throw new HttpsError("not-found", "Startup nao encontrada.");
    }

    const isInvestor = await userIsInvestor(startupId, user.uid);
    const publicQuestions = await listQuestionsByVisibility(startupId, "publica");
    const privateQuestions = isInvestor
      ? await listQuestionsByVisibility(startupId, "privada")
      : [];

    return {
      data: {
        ...startup,
        publicQuestions,
        investorQuestions: privateQuestions,
        access: {
          isInvestor,
          canSendPrivateQuestions: isInvestor,
          canViewInvestorQuestions: isInvestor,
        },
      },
    };
  }
);
