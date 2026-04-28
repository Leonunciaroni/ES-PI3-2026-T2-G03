import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {db} from "../shared/firebase.js";
import {TwoFactorCodeDocument} from "../types/index.js";

const collection = db.collection("two_factor_codes");

const CODE_TTL_MS = 5 * 60 * 1000; // 5 minutos
const MAX_ATTEMPTS = 5;

/** Salva (ou substitui) um código 2FA para o uid informado. */
export async function saveCode(uid: string, code: string): Promise<void> {
  const expiresAt = Timestamp.fromMillis(Date.now() + CODE_TTL_MS);
  const doc: TwoFactorCodeDocument = {
    code,
    expiresAt,
    attempts: 0,
    createdAt: FieldValue.serverTimestamp(),
  };
  await collection.doc(uid).set(doc);
}

export type VerifyResult =
  | {ok: true}
  | {ok: false; reason: "not_found" | "expired" | "max_attempts" | "invalid"};

/**
 * Verifica o código informado contra o documento salvo.
 * Incrementa tentativas em caso de falha; apaga o documento em caso de sucesso.
 */
export async function verifyCode(
  uid: string,
  code: string
): Promise<VerifyResult> {
  const ref = collection.doc(uid);
  const snap = await ref.get();

  if (!snap.exists) {
    return {ok: false, reason: "not_found"};
  }

  const data = snap.data() as TwoFactorCodeDocument;

  if (data.expiresAt.toMillis() < Date.now()) {
    await ref.delete();
    return {ok: false, reason: "expired"};
  }

  if (data.attempts >= MAX_ATTEMPTS) {
    return {ok: false, reason: "max_attempts"};
  }

  if (data.code !== code) {
    await ref.update({attempts: data.attempts + 1});
    return {ok: false, reason: "invalid"};
  }

  await ref.delete();
  return {ok: true};
}
