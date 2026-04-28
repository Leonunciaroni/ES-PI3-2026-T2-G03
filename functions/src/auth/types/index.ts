import {FieldValue, Timestamp} from "firebase-admin/firestore";

/**
 * Dados mínimos do usuário autenticado reutilizados neste módulo.
 */
export type AuthenticatedUser = {
  uid: string;
  email?: string;
};

/**
 * Documento armazenado em `two_factor_codes/{uid}`.
 *
 * - `code`: OTP de 6 dígitos gerado no envio.
 * - `expiresAt`: timestamp de expiração (5 min após envio).
 * - `attempts`: contador de tentativas inválidas (bloqueio após 5).
 * - `createdAt`: servidor — serve de auditoria.
 */
export type TwoFactorCodeDocument = {
  code: string;
  expiresAt: Timestamp;
  attempts: number;
  createdAt: FieldValue;
};
