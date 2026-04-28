import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import * as nodemailer from "nodemailer";
import {requireAuthenticatedUser} from "../shared/auth.js";
import {normalizeString} from "../shared/validation.js";
import {saveCode, verifyCode} from "../repositories/twoFactorRepository.js";
import {AuthenticatedUser} from "../types/index.js";

/**
 * Uma única callable para 2FA (`action: "send"` ou `"verify"`).
 *
 * Reduz atualizações paralelas de duas Cloud Functions (v2/Cloud Run),
 * que costumam falhar intermitentemente no deploy.
 *
 * - `send`: gera OTP, grava Firestore, envia e-mail.
 * - `verify`: valida OTP (6 dígitos).
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
      "Conta sem e-mail associado nao pode usar 2FA por e-mail."
    );
  }

  const code = generateCode();
  await saveCode(user.uid, code);
  await sendEmail(user.email, code);

  logger.info("Codigo 2FA enviado.", {uid: user.uid});
  return {sent: true};
}

async function handleVerify(
  uid: string,
  code: string | undefined
): Promise<{verified: boolean}> {
  if (!code || code.length !== 6 || !/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Informe um codigo de 6 digitos.");
  }

  const result = await verifyCode(uid, code);

  if (result.ok) {
    logger.info("2FA verificado com sucesso.", {uid});
    return {verified: true};
  }

  logger.warn("Falha na verificacao 2FA.", {uid, reason: result.reason});

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

function generateCode(): string {
  const n = Math.floor(Math.random() * 1_000_000);
  return n.toString().padStart(6, "0");
}

function isFunctionsEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true";
}

async function sendEmail(to: string, code: string): Promise<void> {
  const host = process.env.SMTP_HOST?.trim();
  const port = parseInt(process.env.SMTP_PORT ?? "587", 10);
  const smtpUser = process.env.SMTP_USER?.trim();
  const pass = process.env.SMTP_PASS;
  const from = (process.env.SMTP_FROM?.trim() ?? smtpUser ?? "").trim();

  if (!host || !smtpUser || !pass) {
    if (isFunctionsEmulator()) {
      logger.warn("SMTP nao configurado (emulador). Codigo 2FA:", {code, to});
      return;
    }
    logger.error(
      "SMTP nao configurado em producao. Defina SMTP_HOST, SMTP_USER, SMTP_PASS " +
        "em functions/.env e faca deploy (veja functions/.env.example)."
    );
    throw new HttpsError(
      "failed-precondition",
      "Envio de e-mail nao configurado no servidor (SMTP). " +
        "Configure variaveis SMTP nas Cloud Functions e faça deploy."
    );
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: {user: smtpUser, pass},
  });

  try {
    await transporter.sendMail({
      from: `"MesclaInvest" <${from}>`,
      to,
      subject: "Seu código de verificação – MesclaInvest",
      text: `Seu código de verificação é: ${code}\n\nEle expira em 5 minutos.`,
      html: `
      <div style="font-family:sans-serif;max-width:400px;margin:auto">
        <h2 style="color:#6234EA">MesclaInvest</h2>
        <p>Seu código de verificação em duas etapas é:</p>
        <h1 style="letter-spacing:8px;color:#6234EA">${code}</h1>
        <p style="color:#6B7280;font-size:14px">Expira em 5 minutos.<br>
        Se não foi você, ignore este e-mail.</p>
      </div>`,
    });
  } catch (err) {
    logger.error("Falha ao enviar e-mail (nodemailer).", err);
    throw new HttpsError(
      "internal",
      "Nao foi possivel enviar o e-mail agora. Tente reenviar em instantes."
    );
  }
}
