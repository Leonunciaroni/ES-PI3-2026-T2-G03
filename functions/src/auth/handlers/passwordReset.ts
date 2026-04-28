// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Firebase Function (Callable) para **recuperação de senha** via OTP (6 dígitos),
// no mesmo estilo do 2FA.
//
// Escopo (PI3):
// - Enviar um código de verificação por e-mail
// - Validar o código informado pelo utilizador
// - Permitir criar uma nova senha após validação
//
// Observação: o fluxo padrão do Firebase Auth (`sendPasswordResetEmail`) envia um
// link com `oobCode` (não é 6 dígitos). Como a UI do app foi desenhada para OTP,
// implementamos este fluxo próprio via Functions.
//
// Ações disponíveis:
// - action: "send"   -> gera OTP e envia e-mail (resposta sempre {sent:true} p/ não enumerar)
// - action: "verify" -> valida OTP e devolve sessionToken
// - action: "confirm"-> consome sessionToken e atualiza senha via Admin SDK
//
// Dependências:
// - E-mail: `sendVerificationEmail` (usa SMTP_* igual ao `twoFactor.ts`)
// - Persistência: `passwordResetRepository` (Firestore)
// - Atualizar senha: Admin SDK `getAuth().updateUser`

import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {getAuth} from "firebase-admin/auth";
import {normalizeString} from "../shared/validation.js";
import {sendVerificationEmail} from "../shared/sendVerificationEmail.js";
import {
  consumeResetSession,
  saveResetCode,
  verifyResetCode,
} from "../repositories/passwordResetRepository.js";

type SendResponse = {sent: true};
type VerifyResponse = {verified: true; sessionToken: string};
type ConfirmResponse = {updated: true};

export const passwordReset = onCall({region: "us-central1"}, async (request) => {
  const action = normalizeString(request.data?.action)?.toLowerCase();

  if (action === "send") {
    const email = normalizeString(request.data?.email);
    return handleSend(email);
  }

  if (action === "verify") {
    const email = normalizeString(request.data?.email);
    const code = normalizeString(request.data?.code);
    return handleVerify(email, code);
  }

  if (action === "confirm") {
    const sessionToken = normalizeString(request.data?.sessionToken);
    const newPassword = normalizeString(request.data?.newPassword);
    return handleConfirm(sessionToken, newPassword);
  }

  throw new HttpsError("invalid-argument", "Informe action: send, verify ou confirm.");
});

function generateCode(): string {
  // OTP numérico de 6 dígitos (000000-999999), igual ao 2FA.
  const n = Math.floor(Math.random() * 1_000_000);
  return n.toString().padStart(6, "0");
}

function isEmailPlausible(email: string): boolean {
  // Validação simples (não substitui validações do Firebase/servidor).
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
}

async function handleSend(email?: string): Promise<SendResponse> {
  if (!email || !isEmailPlausible(email)) {
    // Resposta neutra (não enumera e-mails/contas).
    return {sent: true};
  }

  const normalizedEmail = email.trim().toLowerCase();

  // Não revelar se utilizador existe: só omitimos envio em `auth/user-not-found`.
  // Outros erros do Admin (rede, permissões) propagam para não mascarar falhas.
  try {
    await getAuth().getUserByEmail(normalizedEmail);
  } catch (e: unknown) {
    const err = e as {code?: string; message?: string};
    if (err.code === "auth/user-not-found") {
      logger.info("passwordReset send: conta inexistente (resposta neutra).", {
        domain: normalizedEmail.includes("@")
          ? normalizedEmail.split("@")[1]
          : "",
      });
      return {sent: true};
    }
    logger.error("passwordReset send: getUserByEmail falhou.", {
      code: err.code,
      message: err.message,
    });
    throw new HttpsError(
      "internal",
      "Nao foi possivel validar o e-mail agora. Tente novamente em instantes."
    );
  }

  const code = generateCode();
  // Salva hash do OTP em Firestore e envia e-mail via SMTP.
  await saveResetCode(normalizedEmail, code);
  await sendVerificationEmail(normalizedEmail, code, "password_reset");

  logger.info("Codigo de reset enviado.", {email: normalizedEmail});
  return {sent: true};
}

async function handleVerify(
  email?: string,
  code?: string
): Promise<VerifyResponse> {
  if (!email || !isEmailPlausible(email)) {
    throw new HttpsError("invalid-argument", "Informe um e-mail valido.");
  }
  if (!code || code.length !== 6 || !/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Informe um codigo de 6 digitos.");
  }

  const normalizedEmail = email.trim().toLowerCase();
  // Se ok, devolve sessionToken (prova temporária) para liberar a etapa "confirm".
  const result = await verifyResetCode(normalizedEmail, code);

  if (result.ok) {
    logger.info("Reset verificado.", {email: normalizedEmail});
    return {verified: true, sessionToken: result.sessionToken};
  }

  logger.warn("Falha na verificacao de reset.", {email: normalizedEmail, reason: result.reason});

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
    default:
      throw new HttpsError("internal", "Falha inesperada na verificacao.");
  }
}

async function handleConfirm(
  sessionToken?: string,
  newPassword?: string
): Promise<ConfirmResponse> {
  if (!sessionToken || sessionToken.length < 32) {
    throw new HttpsError("invalid-argument", "Sessao invalida. Verifique o codigo novamente.");
  }
  if (!newPassword || newPassword.length < 8) {
    throw new HttpsError("invalid-argument", "Informe uma nova senha valida.");
  }

  const session = await consumeResetSession(sessionToken);
  if (!session.ok) {
    throw new HttpsError("not-found", "Sessao expirada. Solicite um novo codigo.");
  }

  let uid: string;
  try {
    const user = await getAuth().getUserByEmail(session.email);
    uid = user.uid;
  } catch {
    // Mantém mensagem genérica
    throw new HttpsError("internal", "Nao foi possivel atualizar a senha agora.");
  }

  // Atualiza senha no Firebase Auth (Admin SDK). A validação forte de senha fica no app.
  await getAuth().updateUser(uid, {password: newPassword});

  logger.info("Senha atualizada via reset.", {uid});
  return {updated: true};
}

