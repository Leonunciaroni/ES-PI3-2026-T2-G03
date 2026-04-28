// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Envio de e-mail de verificação (OTP) via SMTP usando Nodemailer.
// Este helper centraliza a lógica para:
// - 2FA (arquivo `twoFactor.ts`)
// - Recuperação de senha via OTP (arquivo `passwordReset.ts`)
//
// Variáveis de ambiente esperadas (Cloud Run / Functions):
// - SMTP_USER: e-mail do remetente/autenticação (ex.: conta Gmail)
// - SMTP_PASS: senha de aplicação (Gmail com 2FA)
// - SMTP_HOST: opcional (se não for Gmail)
// - SMTP_PORT: opcional (padrão 587)
// - SMTP_FROM: opcional (padrão SMTP_USER)
//
// Comportamento no emulador:
// - Se não houver SMTP configurado, a função apenas loga o código e retorna,
//   evitando falhar o fluxo de UI local durante desenvolvimento.

import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import * as nodemailer from "nodemailer";
import {buildMailTransportOptions, resolveSmtpFromEnv} from "./smtpConfig.js";

function isFunctionsEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true";
}

export type VerificationEmailTemplate = "two_factor" | "password_reset";

function subjectFor(template: VerificationEmailTemplate): string {
  switch (template) {
    case "password_reset":
      return "Seu código de recuperação de senha – MesclaInvest";
    case "two_factor":
    default:
      return "Seu código de verificação – MesclaInvest";
  }
}

function headingFor(template: VerificationEmailTemplate): string {
  switch (template) {
    case "password_reset":
      return "Seu código de recuperação de senha é:";
    case "two_factor":
    default:
      return "Seu código de verificação em duas etapas é:";
  }
}

function bodyTextFor(template: VerificationEmailTemplate, code: string): string {
  const purpose =
    template === "password_reset" ? "recuperação de senha" : "verificação";
  return `Seu código de ${purpose} é: ${code}\n\nEle expira em 5 minutos.`;
}

function bodyHtmlFor(template: VerificationEmailTemplate, code: string): string {
  return `
  <div style="font-family:sans-serif;max-width:420px;margin:auto">
    <h2 style="color:#6234EA">MesclaInvest</h2>
    <p>${headingFor(template)}</p>
    <h1 style="letter-spacing:8px;color:#6234EA">${code}</h1>
    <p style="color:#6B7280;font-size:14px">
      Expira em 5 minutos.<br>
      Se não foi você, ignore este e-mail.
    </p>
  </div>`;
}

export async function sendVerificationEmail(
  to: string,
  code: string,
  template: VerificationEmailTemplate
): Promise<void> {
  const cfg = resolveSmtpFromEnv();

  if (!cfg) {
    // Sem SMTP configurado: exibe o código nos logs para que o desenvolvedor
    // possa testá-lo manualmente (emulador ou Cloud Run sem SMTP).
    // Em produção, configure SMTP_USER e SMTP_PASS no Cloud Run para envio real.
    logger.warn(
      "SMTP nao configurado. Codigo de verificacao disponivel nos logs apenas.",
      {code, to, template, emulator: isFunctionsEmulator()}
    );
    return;
  }

  const transporter = nodemailer.createTransport(buildMailTransportOptions(cfg));

  try {
    await transporter.sendMail({
      from: `"MesclaInvest" <${cfg.from}>`,
      to,
      subject: subjectFor(template),
      text: bodyTextFor(template, code),
      html: bodyHtmlFor(template, code),
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

