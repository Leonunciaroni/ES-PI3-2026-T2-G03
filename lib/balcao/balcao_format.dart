// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Formatação de números do Balcão para exibição em **pt-BR** (vírgula decimal),
// alinhada ao uso de [formatBrl] na Carteira.
//
// Contrato mercado × backend: [`functions/src/wallet/shared/constants.ts`]
// usa `EPSILON_BRL = 0.06` em `assertAmountMatchesTrade`. Este ficheiro
// expõe pares `(amountBrl, tokens)` coerentes com essa tolerância.

/// Tolerância em reais, espelho de `EPSILON_BRL` nas Cloud Functions.
const double balcaoEpsilonBrl = 0.06;

/// Total em real arredondado a **centavos** antes de montar chamadas ao backend.
double balcaoRoundCentavos(double brl) {
  if (!brl.isFinite) {
    return 0;
  }
  return (brl * 100).round() / 100.0;
}

/// Par válido para `trade_buy` / `trade_sell` quando `startup.tokenPrice` é o
/// mesmo que o servidor lê (`preco_token`).
class BalcaoMercadoResolved {
  const BalcaoMercadoResolved({
    required this.amountBrl,
    required this.tokens,
  });

  final double amountBrl;
  final double tokens;

  bool get isValid => amountBrl > 0 && tokens > 0;
}

bool _balcaoImpliedAmountOk(
  double amountBrl,
  double tokens,
  double tokenPriceBrl,
) {
  if (tokens <= 0 || !(tokens.isFinite) || !(tokenPriceBrl > 0)) {
    return false;
  }
  final implied = tokens * tokenPriceBrl;
  return (amountBrl - implied).abs() <= balcaoEpsilonBrl + 1e-12;
}

/// À mercado definido por **valor em reais** (compra ou venda em R$).
BalcaoMercadoResolved balcaoResolveMercadoDesdeBrl(
  double valorBrlInformado,
  double precoTokenBrl,
) {
  if (!(precoTokenBrl > 0) || !(precoTokenBrl.isFinite)) {
    return const BalcaoMercadoResolved(amountBrl: 0, tokens: 0);
  }

  double amount = balcaoRoundCentavos(valorBrlInformado);
  if (amount <= 0) {
    return const BalcaoMercadoResolved(amountBrl: 0, tokens: 0);
  }

  double tokens = amount / precoTokenBrl;
  if (_balcaoImpliedAmountOk(amount, tokens, precoTokenBrl)) {
    return BalcaoMercadoResolved(amountBrl: amount, tokens: tokens);
  }

  double implied = tokens * precoTokenBrl;
  amount = balcaoRoundCentavos(implied);
  tokens = amount / precoTokenBrl;
  implied = tokens * precoTokenBrl;
  if (_balcaoImpliedAmountOk(amount, tokens, precoTokenBrl)) {
    return BalcaoMercadoResolved(amountBrl: amount, tokens: tokens);
  }

  for (final int i in <int>[-3, -2, -1, 1, 2, 3]) {
    final double a = balcaoRoundCentavos(amount + i * 0.01);
    if (a <= 0) {
      continue;
    }
    final double t = a / precoTokenBrl;
    if (_balcaoImpliedAmountOk(a, t, precoTokenBrl)) {
      return BalcaoMercadoResolved(amountBrl: a, tokens: t);
    }
  }

  return BalcaoMercadoResolved(amountBrl: amount, tokens: tokens);
}

/// À mercado quando o utilizador define **quantidade de tokens** (tipicamente na venda).
BalcaoMercadoResolved balcaoResolveMercadoDesdeQuantidadeTokens(
  double quantidadeTokens,
  double precoTokenBrl,
) {
  if (!(quantidadeTokens > 0) || !(precoTokenBrl > 0) || !(precoTokenBrl.isFinite)) {
    return const BalcaoMercadoResolved(amountBrl: 0, tokens: 0);
  }

  double amount = balcaoRoundCentavos(quantidadeTokens * precoTokenBrl);
  if (amount <= 0) {
    return const BalcaoMercadoResolved(amountBrl: 0, tokens: 0);
  }

  double tokens = amount / precoTokenBrl;
  if (_balcaoImpliedAmountOk(amount, tokens, precoTokenBrl)) {
    return BalcaoMercadoResolved(amountBrl: amount, tokens: tokens);
  }

  double implied = tokens * precoTokenBrl;
  amount = balcaoRoundCentavos(implied);
  tokens = amount / precoTokenBrl;
  if (_balcaoImpliedAmountOk(amount, tokens, precoTokenBrl)) {
    return BalcaoMercadoResolved(amountBrl: amount, tokens: tokens);
  }

  for (final int i in <int>[-3, -2, -1, 1, 2, 3]) {
    final double a = balcaoRoundCentavos(amount + i * 0.01);
    if (a <= 0) {
      continue;
    }
    final double t = a / precoTokenBrl;
    if (_balcaoImpliedAmountOk(a, t, precoTokenBrl)) {
      return BalcaoMercadoResolved(amountBrl: a, tokens: t);
    }
  }

  return BalcaoMercadoResolved(amountBrl: amount, tokens: tokens);
}

/// Formata **quantidade de tokens** ao estilo brasileiro: vírgula como separador
/// decimal e **sem** sequências tipo `10,000000` — inteiros aparecem só como `10`;
/// decimais mostram só as casas necessárias (ex.: `2,5`, `0,25`).
String formatQuantidadeTokensBr(double value) {
  if (value.isNaN || value.isInfinite) return '—';

  // Arredonda levemente para evitar lixo binário (ex.: 2,799999999).
  final arredondado = double.parse(value.toStringAsFixed(8));
  final inteiro = arredondado.roundToDouble();
  if ((arredondado - inteiro).abs() < 1e-8) {
    return inteiro.toInt().toString();
  }

  var s = arredondado.toStringAsFixed(8);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}
