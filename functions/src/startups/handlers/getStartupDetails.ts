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
