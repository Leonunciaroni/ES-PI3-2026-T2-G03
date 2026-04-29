// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Estágios aceitos na callable (filtro `stage`); alinhados ao app Flutter.

import type {StartupStage} from "../types/index.js";

export const allowedStages: StartupStage[] = ["nova", "em_operacao", "em_expansao"];

/** Coleção Firestore usada pelo app mobile (catálogo). */
export const STARTUPS_COLLECTION = "startups";
