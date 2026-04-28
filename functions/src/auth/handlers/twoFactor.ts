import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import * as nodemailer from "nodemailer";
import {requireAuthenticatedUser} from "../shared/auth.js";
import {buildMailTransportOptions, resolveSmtpFromEnv} from "../shared/smtpConfig.js";
import {normalizeString} from "../shared/validation.js";
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
  const cfg = resolveSmtpFromEnv();

  if (!cfg) {
    if (isFunctionsEmulator()) {
      logger.warn("SMTP nao configurado (emulador). Codigo 2FA:", {code, to});
      return;
    }
    logger.error(
      "SMTP nao configurado. Defina SMTP_USER, SMTP_PASS e (se nao for Gmail) SMTP_HOST no Cloud Run."
    );
    throw new HttpsError(
      "failed-precondition",
      "Servidor SMTP nao configurado. No Google Cloud: Cloud Run → servico twofactor "
        + "→ Variaveis: SMTP_USER, SMTP_PASS (senha de aplicacao Gmail), opcional SMTP_FROM. "
        + "Para Gmail basta user @gmail.com; o host smtp.gmail.com e aplicado automaticamente."
    );
  }

  const transporter = nodemailer.createTransport(
    buildMailTransportOptions(cfg)
  );

  try {
    await transporter.sendMail({
      from: `"MesclaInvest" <${cfg.from}>`,
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
  } catch (err: unknown) {
    const e = err as {code?: string; responseCode?: number; message?: string};
    logger.error("Falha ao enviar e-mail (nodemailer).", {
      code: e.code,
      responseCode: e.responseCode,
      message: e.message,
    });

    const authFail =
      e.code === "EAUTH" ||
      e.responseCode === 535 ||
      e.responseCode === 534 ||
      /Invalid login|authentication failed|535/i.test(String(e.message));

    if (authFail) {
      throw new HttpsError(
        "failed-precondition",
        "Gmail recusou o login SMTP: use uma senha de aplicacao (16 caracteres), " +
          "sem espacos, com verificacao em 2 passos ativa na conta. " +
          "Atualize SMTP_PASS no Cloud Run."
      );
    }

    throw new HttpsError(
      "internal",
      "Nao foi possivel enviar o e-mail agora. Tente reenviar em instantes."
    );
  }
}
