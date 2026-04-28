import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import * as nodemailer from "nodemailer";
import {requireAuthenticatedUser} from "../shared/auth.js";
import {saveCode} from "../repositories/twoFactorRepository.js";

/**
 * Gera um OTP de 6 dígitos, salva no Firestore e envia por e-mail.
 *
 * Callable pelo app Flutter após o login Firebase Auth.
 * Requer usuário autenticado; usa o e-mail do token para o envio.
 *
 * Variáveis de ambiente necessárias (definir no Firebase Functions config):
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
 */
export const sendTwoFactorCode = onCall(async (request) => {
  const user = requireAuthenticatedUser(request);

  if (!user.email) {
    throw new HttpsError(
      "failed-precondition",
      "Conta sem e-mail associado nao pode usar 2FA por e-mail."
    );
  }

  const code = _generateCode();
  await saveCode(user.uid, code);

  await _sendEmail(user.email, code);

  logger.info("Codigo 2FA enviado.", {uid: user.uid});

  return {sent: true};
});

/** OTP aleatório de 6 dígitos, com zero-padding à esquerda. */
function _generateCode(): string {
  const n = Math.floor(Math.random() * 1_000_000);
  return n.toString().padStart(6, "0");
}

async function _sendEmail(to: string, code: string): Promise<void> {
  const host = process.env.SMTP_HOST;
  const port = parseInt(process.env.SMTP_PORT ?? "587", 10);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.SMTP_FROM ?? user;

  if (!host || !user || !pass) {
    // Sem SMTP configurado: loga o código localmente (emulador / desenvolvimento).
    logger.warn("SMTP nao configurado. Codigo 2FA (dev only):", {code, to});
    return;
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: {user, pass},
  });

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
}
