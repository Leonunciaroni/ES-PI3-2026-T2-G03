import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import {
  allowedVisibilities,
} from "../shared/constants.js";
import {requireAuthenticatedUser} from "../shared/auth.js";
import {normalizeString} from "../shared/validation.js";
import {
  createQuestion,
  listStartupItems,
  userIsInvestor,
} from "../repositories/startupRepository.js";
import type {
  QuestionVisibility,
  StartupQuestionDocument,
} from "../types/index.js";

export const createStartupQuestion = onCall(
  {region: "us-central1"},
  async (request) => {
    const user = requireAuthenticatedUser(request);
    const startupId = normalizeString(request.data?.startupId);
    const text = normalizeString(request.data?.text);
    const visibilityRaw = normalizeString(request.data?.visibility) ?? "publica";
    const visibility = visibilityRaw.toLowerCase() as QuestionVisibility;

    if (!startupId || !text) {
      throw new HttpsError("invalid-argument", "Informe startupId e text.");
    }
    if (!allowedVisibilities.includes(visibility)) {
      throw new HttpsError(
        "invalid-argument",
        "Visibility invalida. Use publica ou privada."
      );
    }

    const startupItems = await listStartupItems({
      includeDetail: false,
      startupId,
    });
    if (startupItems.length === 0) {
      throw new HttpsError("not-found", "Startup nao encontrada.");
    }

    const isInvestor = await userIsInvestor(startupId, user.uid);
    if (visibility === "privada" && !isInvestor) {
      throw new HttpsError(
        "permission-denied",
        "Somente investidores desta startup podem enviar perguntas privadas."
      );
    }

    const question: StartupQuestionDocument = {
      authorUid: user.uid,
      authorEmail: user.email,
      text,
      visibility,
      createdAt: FieldValue.serverTimestamp(),
    };
    const questionId = await createQuestion(startupId, question);

    return {
      data: {
        id: questionId,
        startupId,
        visibility,
      },
    };
  }
);
