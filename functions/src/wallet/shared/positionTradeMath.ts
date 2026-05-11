/**
 * Autor principal: Pedro Henrique Contardi Soler
 * RA: 25005592
 *
 * Matemática pura de posição (tokens + custo) para compra/venda simulada.
 * Extraída do handler para testes unitários rápidos sem Firestore.
 */

export type SimPosition = {
  tokensHeld: number;
  costBasisBrl: number;
};

export function mergeBuyPosition(
  prev: SimPosition | undefined,
  tokens: number,
  amountBrl: number
): SimPosition {
  const held =
    prev != null && typeof prev.tokensHeld === "number"
      ? prev.tokensHeld
      : 0;
  const cost =
    prev != null && typeof prev.costBasisBrl === "number"
      ? prev.costBasisBrl
      : 0;
  return {
    tokensHeld: held + tokens,
    costBasisBrl: cost + amountBrl,
  };
}

export type SellPositionUpdate =
  | {ok: true; tokensHeld: number; costBasisBrl: number; deletePosition: boolean}
  | {ok: false; reason: "insufficient_tokens"};

/**
 * Atualiza posição após venda de [tokens] (fração do custo removida na proporção da venda).
 */
export function computeSellPositionUpdate(
  prev: SimPosition,
  tokens: number
): SellPositionUpdate {
  let tokensHeld =
    typeof prev.tokensHeld === "number" ? prev.tokensHeld : 0;
  const costBasisBrl =
    typeof prev.costBasisBrl === "number" ? prev.costBasisBrl : 0;

  if (tokensHeld < tokens - 1e-12) {
    return {ok: false, reason: "insufficient_tokens"};
  }

  const costRemoved =
    tokensHeld <= 1e-12 ? 0 : costBasisBrl * (tokens / tokensHeld);

  tokensHeld -= tokens;
  const newCost = Math.max(0, costBasisBrl - costRemoved);

  if (tokensHeld <= 1e-9) {
    return {ok: true, tokensHeld: 0, costBasisBrl: 0, deletePosition: true};
  }

  return {
    ok: true,
    tokensHeld,
    costBasisBrl: newCost,
    deletePosition: false,
  };
}
