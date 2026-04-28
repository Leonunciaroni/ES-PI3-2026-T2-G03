import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {requireAuthenticatedUser} from "../shared/auth.js";
import {normalizeString} from "../shared/validation.js";
import {verifyCode} from "../repositories/twoFactorRepository.js";

/**
 * Verifica o código 2FA informado pelo utilizador.
 *
 * Callable pelo app Flutter na tela de verificação.
 * Requer usuário autenticado e o campo `code` em `request.data`.
 *
 * Retorna `{ verified: true }` em caso de sucesso ou lança [HttpsError].
 */
export const verifyTwoFactorCode = onCall(async (request) => {
  const user = requireAuthenticatedUser(request);
  const code = normalizeString(request.data?.code);

  if (!code || code.length !== 6 || !/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Informe um codigo de 6 digitos.");
  }

  const result = await verifyCode(user.uid, code);

  if (result.ok) {
    logger.info("2FA verificado com sucesso.", {uid: user.uid});
    return {verified: true};
  }

  logger.warn("Falha na verificacao 2FA.", {uid: user.uid, reason: result.reason});

  switch (result.reason) {
    case "not_found":
    case "expired":
      throw new HttpsError(
        "not-found",
        "Codigo expirado ou inexistente. Solicite um novo codigo."
      );
    case "max_attempts":
      throw new HttpsError(
        "resource-exhausted",
        "Numero maximo de tentativas atingido. Solicite um novo codigo."
      );
    case "invalid":
      throw new HttpsError("invalid-argument", "Codigo incorreto.");
  }
});
