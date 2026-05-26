/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Regras puras para o progresso da captação no documento `startups/{id}`.
 *
 * Ideia:
 * - `valor_captado_acumulado_brl` acumula o dinheiro líquido das negociações simuladas
 *   (cada compra soma `amountBrl`, cada venda subtrai).
 * - `progresso_captacao` = captado ÷ `captacao_esperada`, limitado a [0, 1].
 */

/**
 * Lê um número opcional não negativo a partir de um campo Firestore (number ou string).
 */
export function readOptionalNonNegativeNumber(raw: unknown): number | undefined {
  if (typeof raw === "number" && Number.isFinite(raw) && raw >= 0) {
    return raw;
  }
  if (typeof raw === "string") {
    const n = Number(raw.trim().replace(",", "."));
    if (Number.isFinite(n) && n >= 0) {
      return n;
    }
  }
  return undefined;
}

/**
 * Devolve a fração da meta já atingida (0..1).
 *
 * Se não há meta positiva, ou o captado não é válido, devolve 0.
 */
export function computeCaptureProgressFraction(
  valorCaptadoAcumuladoBrl: number,
  captacaoEsperadaBrl: number
): number {
  if (
    !Number.isFinite(captacaoEsperadaBrl) ||
    captacaoEsperadaBrl <= 0 ||
    !Number.isFinite(valorCaptadoAcumuladoBrl) ||
    valorCaptadoAcumuladoBrl <= 0
  ) {
    return 0;
  }
  const ratio = valorCaptadoAcumuladoBrl / captacaoEsperadaBrl;
  if (!Number.isFinite(ratio)) {
    return 0;
  }
  return Math.min(1, Math.max(0, ratio));
}
