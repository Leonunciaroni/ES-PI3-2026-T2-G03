/**
 * Le SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM de process.env.
 *
 * Gmail: host smtp.gmail.com:587 por defeito quando SMTP_USER é @gmail.com.
 */

import type SMTPTransport from "nodemailer/lib/smtp-transport/index.js";

export type ResolvedSmtp = {
  host: string;
  port: number;
  secure: boolean;
  user: string;
  pass: string;
  from: string;
};

export function isLikelyGmailAddress(email: string): boolean {
  return /@gmail\.com$/i.test(email) || /@googlemail\.com$/i.test(email);
}

/** Gmail mostra senhas de app como "xxxx xxxx ..."; o SMTP exige sem espacos. */
function normalizeSmtpPass(raw: string): string {
  return raw.replace(/\s+/g, "").trim();
}

/** Resolve configuracao SMTP ou null se faltar user/pass ou host (nao Gmail). */
export function resolveSmtpFromEnv(): ResolvedSmtp | null {
  const user = process.env.SMTP_USER?.trim();
  const rawPass = process.env.SMTP_PASS;
  if (!user || !rawPass) {
    return null;
  }

  const pass = normalizeSmtpPass(rawPass);
  if (!pass) {
    return null;
  }

  let host = process.env.SMTP_HOST?.trim();
  if (!host) {
    host = isLikelyGmailAddress(user) ? "smtp.gmail.com" : "";
  }
  if (!host) {
    return null;
  }

  const parsedPort = parseInt(process.env.SMTP_PORT ?? "", 10);
  const port =
    Number.isFinite(parsedPort) && parsedPort > 0 ? parsedPort : 587;

  const secure = port === 465;
  const from = (process.env.SMTP_FROM?.trim() ?? user).trim();

  return {
    host,
    port,
    secure,
    user,
    pass,
    from,
  };
}

/**
 * Opcoes nodemailer: Gmail usa `service: "gmail"` (STARTTLS/handshake corretos).
 * Outros SMTP: host/porta/tls explicitos.
 */
export function buildMailTransportOptions(cfg: ResolvedSmtp): SMTPTransport.Options {
  const pass = normalizeSmtpPass(cfg.pass);

  if (isLikelyGmailAddress(cfg.user)) {
    const opts: SMTPTransport.Options = {
      service: "gmail",
      auth: {user: cfg.user, pass},
    };
    return opts;
  }

  return {
    host: cfg.host,
    port: cfg.port,
    secure: cfg.secure,
    auth: {user: cfg.user, pass},
    tls: {
      minVersion: "TLSv1.2",
    },
    requireTLS: !cfg.secure && cfg.port === 587,
  };
}
