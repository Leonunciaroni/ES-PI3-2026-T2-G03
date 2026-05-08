// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Estágios aceitos na callable (filtro `stage`); alinhados ao app Flutter.

import type {QuestionVisibility, StartupStage} from "../types/index.js";

export const allowedStages: StartupStage[] = ["nova", "em_operacao", "em_expansao"];
export const allowedVisibilities: QuestionVisibility[] = ["publica", "privada"];

/** Coleção Firestore usada pelo app mobile (catálogo). */
export const STARTUPS_COLLECTION = "startups";
export const USERS_COLLECTION = "users";
export const STARTUP_FIELD_INVESTOR_UIDS = "investorUids";
export const USER_FIELD_INVESTOR_STARTUP_IDS = "investorStartupIds";
