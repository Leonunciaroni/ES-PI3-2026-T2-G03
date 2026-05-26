// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Resolve nome de exibição do investidor para o Order Book.

import {getFirestore} from "firebase-admin/firestore";

import {USERS_COLLECTION} from "./constants.js";

/**
 * Obtém o nome para exibir no livro de ordens.
 *
 * Ordem de fallback: `users/{uid}.name` → prefixo do e-mail → "Investidor".
 */
export async function resolveDisplayName(
  uid: string,
  email?: string
): Promise<string> {
  const db = getFirestore();
  const userSnap = await db.collection(USERS_COLLECTION).doc(uid).get();
  const nameRaw = userSnap.data()?.name;
  if (typeof nameRaw === "string") {
    const trimmed = nameRaw.trim();
    if (trimmed.length > 0) {
      return trimmed.length > 80 ? trimmed.slice(0, 80) : trimmed;
    }
  }

  if (typeof email === "string" && email.includes("@")) {
    const prefix = email.split("@")[0]?.trim();
    if (prefix && prefix.length > 0) {
      return prefix.length > 80 ? prefix.slice(0, 80) : prefix;
    }
  }

  return "Investidor";
}
