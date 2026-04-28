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
// Comportamento:
// - Emulador sem SMTP: apenas loga o OTP (não falha o fluxo de UI local).
// - Produção sem SMTP nesta callable: `HttpsError failed-precondition` com
//   instrução para copiar variáveis do serviço Cloud Run do `twofactor`.

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
    // Emulador: sem .env/SMTP — só loga o OTP para testes locais.
    if (isFunctionsEmulator()) {
      logger.warn(
        "SMTP nao configurado (emulador). Codigo de verificacao nos logs apenas.",
        {code, to, template}
      );
      return;
    }

    // Produção: cada callable v2 vira um **serviço Cloud Run** com env próprio.
    // Se o 2FA envia e-mail mas esta function nao, copie SMTP_* do servico
    // `twofactor` para o servico desta function (ex.: `passwordreset`).
    logger.error("SMTP nao configurado neste servico Cloud Run.", {to, template});
    throw new HttpsError(
      "failed-precondition",
      "Envio de e-mail nao configurado nesta function. No Google Cloud: Cloud Run → "
        + "servico desta callable (ex.: passwordreset) → Variaveis: SMTP_USER, SMTP_PASS, "
        + "opcional SMTP_FROM. Copie as mesmas variaveis do servico `twofactor`."
    );
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

