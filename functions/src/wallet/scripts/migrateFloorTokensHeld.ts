// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
//
// Script one-off: aplica Math.floor em `tokensHeld` fracionários em
// `sim_wallet/{uid}/positions/{startupId}`.
//
// Uso (a partir de `functions/`):
//   npm run migrate:floor-tokens-held:dry   # simulação
//   npm run migrate:floor-tokens-held       # grava no Firestore
//
// Credenciais: `firebase login` ou `GOOGLE_APPLICATION_CREDENTIALS`.
// Emulador: `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080` (project id lido de `.firebaserc`).
// Ledger histórico não é alterado.

import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, type Firestore} from "firebase-admin/firestore";
import dotenv from "dotenv";
import * as fs from "node:fs";
import * as path from "node:path";

import {POSITION_FIELD_TOKENS_LOCKED} from "../../balcao/shared/constants.js";
import {
  ROOT,
  STARTUP_FIELD_INVESTOR_UIDS,
  STARTUPS_COLLECTION,
  USER_FIELD_INVESTOR_STARTUP_IDS,
  USERS_COLLECTION,
} from "../shared/constants.js";

export type MigrateFloorTokensHeldDetail = {
  walletUid: string;
  startupId: string;
  previousTokensHeld: number;
  action: "skipped" | "updated" | "deleted";
  nextTokensHeld?: number;
  reason?: string;
};

export type MigrateFloorTokensHeldResult = {
  dryRun: boolean;
  walletsScanned: number;
  positionsScanned: number;
  updated: number;
  deleted: number;
  skipped: number;
  details: MigrateFloorTokensHeldDetail[];
};

function readTokensHeld(raw: unknown): number | null {
  if (typeof raw !== "number" || !Number.isFinite(raw)) {
    return null;
  }
  return raw;
}

function readTokensLocked(raw: unknown): number {
  if (typeof raw !== "number" || !Number.isFinite(raw) || raw <= 0) {
    return 0;
  }
  return Math.trunc(raw);
}

/** True quando [held] precisa de floor (fração significativa ou não-inteiro). */
export function tokensHeldNeedsFloorMigration(held: number): boolean {
  if (!Number.isFinite(held) || held <= 0) {
    return false;
  }
  return Math.floor(held) !== held;
}

/**
 * Percorre todas as posições simuladas e normaliza `tokensHeld` com Math.floor.
 * Posições que zeram após floor são apagadas (com limpeza mínima de índices de investidor).
 */
export async function migrateFloorTokensHeld(
  db: Firestore,
  options: {dryRun?: boolean} = {}
): Promise<MigrateFloorTokensHeldResult> {
  const dryRun = options.dryRun === true;
  const result: MigrateFloorTokensHeldResult = {
    dryRun,
    walletsScanned: 0,
    positionsScanned: 0,
    updated: 0,
    deleted: 0,
    skipped: 0,
    details: [],
  };

  const walletsSnap = await db.collection(ROOT).get();
  result.walletsScanned = walletsSnap.size;

  for (const walletDoc of walletsSnap.docs) {
    const uid = walletDoc.id;
    const positionsSnap = await walletDoc.ref.collection("positions").get();

    for (const posDoc of positionsSnap.docs) {
      result.positionsScanned += 1;
      const startupId = posDoc.id;
      const data = posDoc.data();
      const held = readTokensHeld(data.tokensHeld);

      if (held == null) {
        result.skipped += 1;
        result.details.push({
          walletUid: uid,
          startupId,
          previousTokensHeld: 0,
          action: "skipped",
          reason: "tokensHeld ausente ou inválido",
        });
        continue;
      }

      if (!tokensHeldNeedsFloorMigration(held)) {
        result.skipped += 1;
        result.details.push({
          walletUid: uid,
          startupId,
          previousTokensHeld: held,
          action: "skipped",
          reason: "já inteiro",
        });
        continue;
      }

      const floored = Math.floor(held);
      const locked = readTokensLocked(data[POSITION_FIELD_TOKENS_LOCKED]);

      if (locked > floored) {
        result.skipped += 1;
        result.details.push({
          walletUid: uid,
          startupId,
          previousTokensHeld: held,
          action: "skipped",
          reason:
            `tokensLockedInOrders (${locked}) excede saldo após floor (${floored})`,
        });
        continue;
      }

      if (floored <= 0) {
        result.deleted += 1;
        result.details.push({
          walletUid: uid,
          startupId,
          previousTokensHeld: held,
          action: "deleted",
          nextTokensHeld: 0,
        });

        if (dryRun) {
          continue;
        }

        await db.runTransaction(async (trx) => {
          const posRef = posDoc.ref;
          const userRef = db.collection(USERS_COLLECTION).doc(uid);
          const startupRef = db.collection(STARTUPS_COLLECTION).doc(startupId);
          trx.delete(posRef);
          trx.set(
            userRef,
            {[USER_FIELD_INVESTOR_STARTUP_IDS]: FieldValue.arrayRemove(startupId)},
            {merge: true}
          );
          trx.set(
            startupRef,
            {[STARTUP_FIELD_INVESTOR_UIDS]: FieldValue.arrayRemove(uid)},
            {merge: true}
          );
          trx.delete(startupRef.collection("investors").doc(uid));
        });
        continue;
      }

      result.updated += 1;
      result.details.push({
        walletUid: uid,
        startupId,
        previousTokensHeld: held,
        action: "updated",
        nextTokensHeld: floored,
      });

      if (dryRun) {
        continue;
      }

      await posDoc.ref.set(
        {
          tokensHeld: floored,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    }
  }

  return result;
}

function printSummary(result: MigrateFloorTokensHeldResult): void {
  const mode = result.dryRun ? "[DRY-RUN]" : "[APLICADO]";
  console.log(`${mode} Migração tokensHeld (Math.floor)`);
  console.log(`  Carteiras: ${result.walletsScanned}`);
  console.log(`  Posições:  ${result.positionsScanned}`);
  console.log(`  Atualizadas: ${result.updated}`);
  console.log(`  Apagadas:    ${result.deleted}`);
  console.log(`  Ignoradas:   ${result.skipped}`);

  const changed = result.details.filter((d) => d.action !== "skipped");
  if (changed.length === 0) {
    console.log("  Nenhuma posição fracionária encontrada.");
    return;
  }

  console.log("\n  Alterações:");
  for (const row of changed) {
    const next =
      row.action === "deleted"
        ? "→ apagar doc"
        : `→ ${row.nextTokensHeld}`;
    console.log(
      `    ${row.walletUid}/${row.startupId}: ${row.previousTokensHeld} ${next}`
    );
  }
}

const __functionsRoot = process.cwd();

function loadLocalEnv(): void {
  const envPath = path.join(__functionsRoot, ".env");
  if (fs.existsSync(envPath)) {
    dotenv.config({path: envPath});
  }
}

function resolveFirebaseProjectId(): string | undefined {
  if (process.env.GCLOUD_PROJECT?.trim()) {
    return process.env.GCLOUD_PROJECT.trim();
  }
  if (process.env.GOOGLE_CLOUD_PROJECT?.trim()) {
    return process.env.GOOGLE_CLOUD_PROJECT.trim();
  }

  const rcPath = path.join(__functionsRoot, "..", ".firebaserc");
  if (!fs.existsSync(rcPath)) {
    return undefined;
  }

  try {
    const raw = fs.readFileSync(rcPath, "utf8");
    const parsed = JSON.parse(raw) as {projects?: {default?: string}};
    const id = parsed.projects?.default?.trim();
    return id && id.length > 0 ? id : undefined;
  } catch {
    return undefined;
  }
}

function ensureFirebaseProjectId(): void {
  const existing = resolveFirebaseProjectId();
  if (existing) {
    process.env.GCLOUD_PROJECT ??= existing;
    process.env.GOOGLE_CLOUD_PROJECT ??= existing;
  }
}

async function runCli(): Promise<void> {
  loadLocalEnv();
  ensureFirebaseProjectId();

  if (getApps().length === 0) {
    initializeApp();
  }

  const dryRun = process.argv.includes("--dry-run");
  const db = getFirestore();
  const result = await migrateFloorTokensHeld(db, {dryRun});
  printSummary(result);
}

const executedDirectly =
  typeof process.argv[1] === "string" &&
  (process.argv[1].endsWith("migrateFloorTokensHeld.js") ||
    process.argv[1].endsWith("migrateFloorTokensHeld.ts"));

if (executedDirectly) {
  runCli().catch((err: unknown) => {
    console.error("Falha na migração:", err);
    process.exitCode = 1;
  });
}
