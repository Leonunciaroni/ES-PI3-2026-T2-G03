// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592

import type {FieldValue} from "firebase-admin/firestore";

export type StartupStage = "nova" | "em_operacao" | "em_expansao";

export type QuestionVisibility = "publica" | "privada";

export type StartupQuestionDocument = {
  authorUid: string;
  authorEmail?: string;
  text: string;
  visibility: QuestionVisibility;
  answer?: string;
  createdAt: FieldValue;
};

export type StartupQuestionView = {
  id: string;
  text: string;
  answer: string | null;
  visibility: QuestionVisibility;
  authorUid: string;
  createdAt: string | null;
};
