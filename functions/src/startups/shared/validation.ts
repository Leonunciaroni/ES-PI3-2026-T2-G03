// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Mesma semântica de [functions/src/auth/shared/validation.ts]: strings vazias viram undefined.

export function normalizeString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}
