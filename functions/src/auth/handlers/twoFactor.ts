// Principal: Miguel Fernandes Costacurta - 25003110
// RA: 25003110
//
// Firebase Function (Callable) para **autenticação em duas etapas** (2FA).
//
// Escopo (PI3):
// - Enviar um código OTP para o e-mail do usuário autenticado
// - Validar o código informado pelo usuário
//
// Ações disponíveis:

import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {requireAuthenticatedUser} from "../shared/auth.js";
import {normalizeString} from "../shared/validation.js";
import {sendVerificationEmail} from "../shared/sendVerificationEmail.js";
import {saveCode, verifyCode} from "../repositories/twoFactorRepository.js";
import {AuthenticatedUser} from "../types/index.js";

/**
 * Uma única callable para 2FA (`action: "send"` ou `"verify"`).
 *
 * SMTP (produção): defina estas variáveis no **serviço Cloud Run** criado pela
 * function (nome em minúsculas, ex.: `twofactor`):
 * https://console.cloud.google.com/run?project=PROJECT_ID → editar revisão → Variáveis
 *
 * Ou crie `functions/.env` (não commit) e rode `firebase deploy`; o CLI pode injetar
 * variáveis conforme versão do Firebase CLI.
 *
 * Variáveis: SMTP_HOST, SMTP_PORT (587), SMTP_USER, SMTP_PASS, SMTP_FROM
 */
export const twoFactor = onCall({region: "us-central1"}, async (request) => {
  const user = requireAuthenticatedUser(request);
  const action = normalizeString(request.data?.action)?.toLowerCase();

  if (action === "send") {
    return handleSend(user);
  }
  if (action === "verify") {
    const code = normalizeString(request.data?.code);
    return handleVerify(user.uid, code);
  }

  throw new HttpsError(
    "invalid-argument",
    "Informe action: send ou verify."
  );
});

async function handleSend(user: AuthenticatedUser): Promise<{sent: boolean}> {
  if (!user.email) {
    throw new HttpsError(
      "failed-precondition",
      "Conta sem e-mail associado não pode usar 2FA por e-mail."
    );
  }

  const code = generateCode();
  await saveCode(user.uid, code);
  await sendVerificationEmail(user.email, code, "two_factor");

  logger.info("Código 2FA enviado.", {uid: user.uid});
  return {sent: true};
}

async function handleVerify(
  uid: string,
  code: string | undefined
): Promise<{verified: boolean}> {
  if (!code || code.length !== 6 || !/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Informe um código de 6 dígitos.");
  }

  const result = await verifyCode(uid, code);

  if (result.ok) {
    logger.info("2FA verificado com sucesso.", {uid});
    return {verified: true};
  }

  logger.warn("Falha na verificação 2FA.", {uid, reason: result.reason});

  switch (result.reason) {
    case "not_found":
    case "expired":
      throw new HttpsError(
        "not-found",
        "Código expirado ou inexistente. Solicite um novo código."
      );
    case "max_attempts":
      throw new HttpsError(
        "resource-exhausted",
        "Número máximo de tentativas atingido. Solicite um novo código."
      );
    case "invalid":
      throw new HttpsError("invalid-argument", "Código incorreto.");
    default:
      throw new HttpsError("internal", "Falha inesperada na verificação.");
  }
}

function generateCode(): string {
  const n = Math.floor(Math.random() * 1_000_000);
  return n.toString().padStart(6, "0");
}
