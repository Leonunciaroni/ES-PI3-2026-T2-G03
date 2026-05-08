// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Repositório Firestore do fluxo de recuperação de senha via OTP.
//
// Por que existe:
// - O reset padrão do Firebase Auth usa `oobCode` em link (não 6 dígitos).
// - A UI do app foi desenhada para receber OTP (6 dígitos), então guardamos o OTP
//   (em hash) e emitimos um token de sessão curto após a validação.
//
// Coleções:
// - password_reset_codes: 1 doc por e-mail (id = SHA-256(email normalizado))
// - password_reset_sessions: 1 doc por sessão (id = SHA-256(sessionToken))
//
// Segurança:
// - OTP nunca é salvo em claro; apenas hash (SHA-256).
// - A resposta "send" é sempre neutra para evitar enumeração de contas.
// - `consumeResetSession` apaga a sessão ao consumir (one-time).

import {FieldValue, Timestamp} from "firebase-admin/firestore";
import crypto from "node:crypto";
import {db} from "../shared/firebase.js";

const CODE_TTL_MS = 5 * 60 * 1000; // 5 minutos
const SESSION_TTL_MS = 10 * 60 * 1000; // 10 minutos
const MAX_ATTEMPTS = 5;

const codesCollection = db.collection("password_reset_codes");
const sessionsCollection = db.collection("password_reset_sessions");

function hash(value: string): string {
  // SHA-256 em hex para chaves/valores derivados.
  return crypto.createHash("sha256").update(value).digest("hex");
}

function normalizeEmail(email: string): string {
  // Canoniza o e-mail para evitar múltiplos registros por variação de caixa/espaço.
  return email.trim().toLowerCase();
}

export async function saveResetCode(email: string, code: string): Promise<void> {
  const key = hash(normalizeEmail(email));
  const expiresAt = Timestamp.fromMillis(Date.now() + CODE_TTL_MS);
  await codesCollection.doc(key).set({
    // OTP em hash (nunca em claro)
    codeHash: hash(code),
    attempts: 0,
    expiresAt,
    createdAt: FieldValue.serverTimestamp(),
  });
}

export type VerifyResetCodeResult =
  | {ok: true; sessionToken: string}
  | {ok: false; reason: "not_found" | "expired" | "max_attempts" | "invalid"};

export async function verifyResetCode(
  email: string,
  code: string
): Promise<VerifyResetCodeResult> {
  const key = hash(normalizeEmail(email));
  const ref = codesCollection.doc(key);
  const snap = await ref.get();

  if (!snap.exists) {
    return {ok: false, reason: "not_found"};
  }

  const data = snap.data() as {
    codeHash?: string;
    attempts?: number;
    expiresAt?: Timestamp;
  };

  const expiresAtMs = data.expiresAt?.toMillis?.() ?? 0;
  if (expiresAtMs < Date.now()) {
    await ref.delete();
    return {ok: false, reason: "expired"};
  }

  const attempts = typeof data.attempts === "number" ? data.attempts : 0;
  if (attempts >= MAX_ATTEMPTS) {
    return {ok: false, reason: "max_attempts"};
  }

  const matches = typeof data.codeHash === "string" && data.codeHash === hash(code);
  if (!matches) {
    await ref.update({attempts: FieldValue.increment(1)});
    return {ok: false, reason: "invalid"};
  }

  // Código correto: cria uma sessão de reset e apaga o código para evitar reuso.
  // O token devolvido ao app é "prova" temporária para a etapa confirm.
  const sessionToken = crypto.randomBytes(32).toString("hex");
  const sessionId = hash(sessionToken);
  const sessionExpiresAt = Timestamp.fromMillis(Date.now() + SESSION_TTL_MS);

  await sessionsCollection.doc(sessionId).set({
    email: normalizeEmail(email),
    expiresAt: sessionExpiresAt,
    createdAt: FieldValue.serverTimestamp(),
  });
  await ref.delete();

  return {ok: true, sessionToken};
}

export type ConsumeResetSessionResult =
  | {ok: true; email: string}
  | {ok: false; reason: "not_found" | "expired"};

export async function consumeResetSession(
  sessionToken: string
): Promise<ConsumeResetSessionResult> {
  const sessionId = hash(sessionToken);
  const ref = sessionsCollection.doc(sessionId);
  const snap = await ref.get();

  if (!snap.exists) {
    return {ok: false, reason: "not_found"};
  }

  const data = snap.data() as {email?: string; expiresAt?: Timestamp};
  const expiresAtMs = data.expiresAt?.toMillis?.() ?? 0;
  if (expiresAtMs < Date.now()) {
    await ref.delete();
    return {ok: false, reason: "expired"};
  }

  const email = typeof data.email === "string" ? data.email : "";
  // One-time token: sempre apaga ao consumir (mesmo que falhe depois).
  await ref.delete();
  if (!email) {
    return {ok: false, reason: "not_found"};
  }
  return {ok: true, email};
}

