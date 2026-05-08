// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Callable `listStartups` — mesma ideia do exemplo de aula: auth, filtros, busca, retorno { count, filters, data }.

import {HttpsError, onCall} from "firebase-functions/https";
import {allowedStages, STARTUPS_COLLECTION} from "../shared/constants.js";
import {requireAuthenticatedUser} from "../shared/auth.js";
import {normalizeString} from "../shared/validation.js";
import {listStartupItems, type StartupListItem} from "../repositories/startupRepository.js";
import type {StartupStage} from "../types/index.js";

/**
 * Lista as startups cadastradas no catálogo MesclaInvest.
 *
 * Callable usada pelo app mobile. Em `data` pode enviar:
 * - `stage`: filtro opcional por estágio (`nova`, `em_operacao`, `em_expansao`).
 * - `search`: texto opcional (busca em nome, descrição, categoria, tags).
 * - `includeDetail: true` para trazer o bloco `detail` (detalhe + Balcão enriquecido).
 * - `startupId`: opcional; com `includeDetail` retorna só esse documento (eficiente na tela de detalhe).
 */
export const listStartups = onCall({region: "us-central1"}, async (request) => {
  requireAuthenticatedUser(request);

  const stage = normalizeString(request.data?.stage);
  const searchRaw = normalizeString(request.data?.search);
  const search = searchRaw != null ? searchRaw.toLocaleLowerCase("pt-BR") : undefined;
  const includeDetail = request.data?.includeDetail === true;
  const startupId = normalizeString(request.data?.startupId);

  if (stage != null && !allowedStages.includes(stage as StartupStage)) {
    throw new HttpsError(
      "invalid-argument",
      "Filtro stage invalido. Use nova, em_operacao ou em_expansao."
    );
  }

  const startups = (await listStartupItems({includeDetail, startupId}))
    .filter((s: StartupListItem) => !stage || s.stage === stage)
    .filter((s: StartupListItem) => {
      if (search == null || search.length === 0) {
        return true;
      }
      const searchable = [
        s.name,
        s.shortDescription,
        s.stage,
        s.category,
        ...s.tags,
      ]
        .join(" ")
        .toLocaleLowerCase("pt-BR");
      return searchable.includes(search);
    })
    .sort((left, right) => left.name.localeCompare(right.name, "pt-BR"));

  return {
    count: startups.length,
    filters: {
      availableStages: allowedStages,
      stage: stage ?? null,
      search: searchRaw ?? null,
      includeDetail,
      startupId: startupId ?? null,
      collection: STARTUPS_COLLECTION,
    },
    data: startups,
  };
});
