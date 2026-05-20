// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Lê metadados da startup para gravar nas ordens.

import type {DocumentData} from "firebase-admin/firestore";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";

import {
  STARTUP_FIELD_NAME,
  STARTUP_FIELD_SIGLA,
  STARTUPS_COLLECTION,
} from "./constants.js";

export type StartupOrderMeta = {
  startupName: string;
  tokenSigla: string;
};

/** Busca nome e sigla da startup para denormalizar na ordem. */
export async function readStartupOrderMeta(
  startupId: string
): Promise<StartupOrderMeta> {
  const db = getFirestore();
  const snap = await db.collection(STARTUPS_COLLECTION).doc(startupId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Startup não encontrada no catálogo.");
  }
  return parseStartupOrderMeta(snap.data());
}

export function parseStartupOrderMeta(data: DocumentData | undefined): StartupOrderMeta {
  let startupName = "";
  if (typeof data?.[STARTUP_FIELD_NAME] === "string") {
    startupName = data[STARTUP_FIELD_NAME].trim();
  }
  if (!startupName && typeof data?.name === "string") {
    startupName = data.name.trim();
  }
  if (!startupName) {
    startupName = "Startup";
  }

  let tokenSigla = "";
  if (typeof data?.[STARTUP_FIELD_SIGLA] === "string") {
    tokenSigla = data[STARTUP_FIELD_SIGLA].trim().toUpperCase();
  }
  if (!tokenSigla) {
    const emitidos = data?.tokens_emitidos;
    if (emitidos && typeof emitidos === "object") {
      const sig = (emitidos as Record<string, unknown>).sigla;
      if (typeof sig === "string" && sig.trim()) {
        tokenSigla = sig.trim().toUpperCase();
      }
    }
  }
  if (!tokenSigla) {
    tokenSigla = startupName.length <= 5
      ? startupName.toUpperCase()
      : `${startupName.substring(0, 4).toUpperCase()}…`;
  }

  return {
    startupName: startupName.slice(0, 200),
    tokenSigla: tokenSigla.slice(0, 24),
  };
}
