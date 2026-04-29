// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Lê documentos da coleção `startups` no Firestore e monta itens para a callable.
// Os nomes dos campos seguem [lib/catalog/services/startup_firestore_schema.dart].

import {db} from "../../auth/shared/firebase.js";
import {STARTUPS_COLLECTION} from "../shared/constants.js";
import type {StartupStage} from "../types/index.js";

/** Campos extras quando `includeDetail: true` — espelham o documento Firestore. */
export type StartupDetailPayload = {
  descricao?: string | null;
  captacao_headline?: string | null;
  valor_captado_reais?: number | null;
  meta_captacao_reais?: number | null;
  valuation_headline?: string | null;
  valuation_rodada?: string | null;
  valuation_tendencia?: string | null;
  grafico_valuation?: Record<string, unknown> | null;
  sede?: string | null;
  anoDeInicio?: number | null;
  video_demo?: string | null;
  socios?: unknown;
  mentores_conselho?: unknown;
  estrutura_societaria?: unknown;
  receita_mensal?: number | null;
  tokens_emitidos?: Record<string, unknown> | null;
  modelo_negocio?: unknown;
};

/** Um item da lista retornada pela Function (resumo + opcional detalhe). */
export type StartupListItem = {
  id: string;
  name: string;
  shortDescription: string;
  /** Texto cru do setor (mesmo que no Firestore). */
  setor: string;
  category: string;
  stage: StartupStage;
  sigla?: string;
  logoPath?: string;
  tokenPrice: number;
  captureProgress: number;
  yieldPercentLabel: string;
  tags: string[];
  detail?: StartupDetailPayload | null;
};

const kNomeStartup = "nome_startup";
const kDescricao = "descricao";
const kSetor = "setor";
const kEstagio = "estagio";
const kSigla = "sigla";
const kLogoPath = "logoPath";
const kLogoPathSnake = "logo_path";
const kPrecoToken = "preco_token";
const kProgressoCaptacao = "progresso_captacao";
const kRendimentoLabel = "rendimento_label";

function readString(d: Record<string, unknown>, key: string): string {
  const v = d[key];
  if (typeof v === "string") {
    return v;
  }
  if (v != null) {
    return String(v);
  }
  return "";
}

function readOptionalString(d: Record<string, unknown>, key: string): string | undefined {
  const s = readString(d, key).trim();
  return s.length > 0 ? s : undefined;
}

function readOptionalDouble(d: Record<string, unknown>, key: string): number | undefined {
  const v = d[key];
  if (typeof v === "number" && Number.isFinite(v)) {
    return v;
  }
  if (typeof v === "string") {
    const p = v.trim().replace(",", ".");
    const n = Number(p);
    return Number.isFinite(n) ? n : undefined;
  }
  return undefined;
}

function foldPortuguese(s: string): string {
  return s
    .toLowerCase()
    .trim()
    .replace(/á/g, "a")
    .replace(/à/g, "a")
    .replace(/â/g, "a")
    .replace(/ã/g, "a")
    .replace(/é/g, "e")
    .replace(/ê/g, "e")
    .replace(/í/g, "i")
    .replace(/ó/g, "o")
    .replace(/ô/g, "o")
    .replace(/õ/g, "o")
    .replace(/ú/g, "u")
    .replace(/ç/g, "c");
}

/** Mesma heurística do Dart [parseFirestoreStage]. */
export function parseStageRaw(raw: string): StartupStage {
  const x = foldPortuguese(raw);
  if (x.includes("expans")) {
    return "em_expansao";
  }
  if (x.includes("operac")) {
    return "em_operacao";
  }
  if (x.includes("nova")) {
    return "nova";
  }
  return "nova";
}

function captureProgressFraction(d: Record<string, unknown>): number {
  const v = readOptionalDouble(d, kProgressoCaptacao);
  if (v == null) {
    return 0;
  }
  if (v > 1) {
    return Math.min(1, Math.max(0, v / 100));
  }
  return Math.min(1, Math.max(0, v));
}

function yieldLabel(d: Record<string, unknown>): string {
  const s = readOptionalString(d, kRendimentoLabel);
  if (s != null && s.length > 0) {
    return s;
  }
  return "N/D";
}

function logoPathFrom(d: Record<string, unknown>): string | undefined {
  return readOptionalString(d, kLogoPath) ?? readOptionalString(d, kLogoPathSnake);
}

function buildTags(setor: string, sigla: string | undefined, stage: StartupStage): string[] {
  const tags: string[] = [];
  if (setor.trim().length > 0) {
    tags.push(setor.trim());
  }
  if (sigla != null && sigla.trim().length > 0) {
    tags.push(sigla.trim());
  }
  tags.push(stage);
  return tags;
}

function firstPresentEstrutura(d: Record<string, unknown>): unknown {
  const keys = [
    "estrutura_societaria",
    "estruturaSocietaria",
    "Estrutura societária",
    "estrutura societária",
    "Estrutura Societária",
  ];
  for (const k of keys) {
    const v = d[k];
    if (v === null || v === undefined) {
      continue;
    }
    if (typeof v === "string" && v.trim().length === 0) {
      continue;
    }
    if (Array.isArray(v) && v.length === 0) {
      continue;
    }
    if (typeof v === "object" && !Array.isArray(v) && Object.keys(v as object).length === 0) {
      continue;
    }
    return v;
  }
  return undefined;
}

function detailPayloadFromDoc(d: Record<string, unknown>): StartupDetailPayload {
  return {
    descricao: readOptionalString(d, kDescricao) ?? null,
    captacao_headline: readOptionalString(d, "captacao_headline") ?? null,
    valor_captado_reais: readOptionalDouble(d, "valor_captado_reais") ?? null,
    meta_captacao_reais: readOptionalDouble(d, "meta_captacao_reais") ?? null,
    valuation_headline: readOptionalString(d, "valuation_headline") ?? null,
    valuation_rodada: readOptionalString(d, "valuation_rodada") ?? null,
    valuation_tendencia: readOptionalString(d, "valuation_tendencia") ?? null,
    grafico_valuation: (d["grafico_valuation"] as Record<string, unknown>) ?? null,
    sede: readOptionalString(d, "sede") ?? null,
    anoDeInicio:
      typeof d["anoDeInicio"] === "number"
        ? (d["anoDeInicio"] as number)
        : readOptionalDouble(d, "anoDeInicio") ?? null,
    video_demo: readOptionalString(d, "video_demo") ?? null,
    socios: d["socios"],
    mentores_conselho: d["mentores_conselho"],
    estrutura_societaria: firstPresentEstrutura(d),
    receita_mensal: readOptionalDouble(d, "receita_mensal") ?? null,
    tokens_emitidos: (d["tokens_emitidos"] as Record<string, unknown>) ?? null,
    modelo_negocio: d["modelo_negocio"],
  };
}

function mapDocToItem(
  id: string,
  data: Record<string, unknown>,
  includeDetail: boolean
): StartupListItem | null {
  let name = readString(data, kNomeStartup).trim();
  if (name.length === 0) {
    name = readString(data, "name").trim();
  }
  if (name.length === 0) {
    return null;
  }

  const setorRaw = readString(data, kSetor).trim();
  const category = setorRaw.length === 0 ? "SETOR" : setorRaw.toUpperCase();
  const stage = parseStageRaw(readString(data, kEstagio));
  let shortDescription = readString(data, kDescricao);
  if (shortDescription.trim().length === 0) {
    shortDescription = readString(data, "description");
  }
  const sigla = readOptionalString(data, kSigla);

  const item: StartupListItem = {
    id,
    name,
    shortDescription,
    setor: setorRaw,
    category,
    stage,
    sigla,
    logoPath: logoPathFrom(data),
    tokenPrice: readOptionalDouble(data, kPrecoToken) ?? 0,
    captureProgress: captureProgressFraction(data),
    yieldPercentLabel: yieldLabel(data),
    tags: buildTags(setorRaw, sigla, stage),
  };

  if (includeDetail) {
    item.detail = detailPayloadFromDoc(data);
  }

  return item;
}

export type ListStartupItemsOptions = {
  includeDetail: boolean;
  /** Se informado, só devolve esse documento (útil para detalhe sem varrer a coleção). */
  startupId?: string;
};

/**
 * Lista startups do catálogo.
 * Sem `startupId`: lê todos os documentos da coleção.
 * Com `startupId`: lê apenas esse ID (404 vira lista vazia no handler).
 */
export async function listStartupItems(
  options: ListStartupItemsOptions
): Promise<StartupListItem[]> {
  const {includeDetail, startupId} = options;
  const col = db.collection(STARTUPS_COLLECTION);

  if (startupId != null && startupId.length > 0) {
    const snap = await col.doc(startupId).get();
    if (!snap.exists) {
      return [];
    }
    const data = snap.data() as Record<string, unknown>;
    const item = mapDocToItem(snap.id, data, includeDetail);
    return item != null ? [item] : [];
  }

  const snapshot = await col.get();
  const out: StartupListItem[] = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() as Record<string, unknown>;
    const item = mapDocToItem(doc.id, data, includeDetail);
    if (item != null) {
      out.push(item);
    }
  }
  return out;
}
