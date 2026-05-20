// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
//
// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Formatação de números do Balcão para exibição em **pt-BR** (vírgula decimal),// alinhada ao uso de [formatBrl] na Carteira.
//
// Contrato mercado × backend: [`functions/src/wallet/shared/constants.ts`]
// usa `EPSILON_BRL = 0.06` em `assertAmountMatchesTrade`. Este ficheiro
// expõe pares `(amountBrl, tokens)` coerentes com essa tolerância.
// Tokens são sempre **inteiros** (quantidade informada pelo usuário).

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

  /// Quantidade de tokens — sempre inteiro positivo.
  final int tokens;

  bool get isValid => amountBrl > 0 && tokens > 0;
}

bool _balcaoImpliedAmountOk(
  double amountBrl,
  int tokens,
  double tokenPriceBrl,
) {
  if (tokens <= 0 || !(tokenPriceBrl > 0)) {
    return false;
  }
  final implied = tokens * tokenPriceBrl;
  return (amountBrl - implied).abs() <= balcaoEpsilonBrl + 1e-12;
}

/// Espelha `assertAmountMatchesTrade` nas Cloud Functions (`EPSILON_BRL`).
///
/// Usado antes de chamar `simulateWallet` (ex.: após reautenticar) com cotação
/// lida em tempo real do Firestore.
bool balcaoAmountMatchesTrade(
  double amountBrl,
  int tokens,
  double tokenPriceBrl,
) {
  if (tokens <= 0) return false;
  if (!(tokenPriceBrl > 0) || !tokenPriceBrl.isFinite) return false;
  if (!amountBrl.isFinite) return false;
  return _balcaoImpliedAmountOk(amountBrl, tokens, tokenPriceBrl);
}

/// Negócio à mercado definido por **quantidade inteira de tokens**.
BalcaoMercadoResolved balcaoResolveMercadoDesdeQuantidadeTokens(
  int quantidadeTokens,
  double precoTokenBrl,
) {
  if (quantidadeTokens <= 0 ||
      !(precoTokenBrl > 0) ||
      !(precoTokenBrl.isFinite)) {
    return const BalcaoMercadoResolved(amountBrl: 0, tokens: 0);
  }

  double amount = balcaoRoundCentavos(quantidadeTokens * precoTokenBrl);
  if (amount <= 0) {
    return const BalcaoMercadoResolved(amountBrl: 0, tokens: 0);
  }

  if (_balcaoImpliedAmountOk(amount, quantidadeTokens, precoTokenBrl)) {
    return BalcaoMercadoResolved(amountBrl: amount, tokens: quantidadeTokens);
  }

  for (final int i in <int>[-3, -2, -1, 1, 2, 3]) {
    final double a = balcaoRoundCentavos(amount + i * 0.01);
    if (a <= 0) {
      continue;
    }
    if (_balcaoImpliedAmountOk(a, quantidadeTokens, precoTokenBrl)) {
      return BalcaoMercadoResolved(amountBrl: a, tokens: quantidadeTokens);
    }
  }

  return const BalcaoMercadoResolved(amountBrl: 0, tokens: 0);
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
