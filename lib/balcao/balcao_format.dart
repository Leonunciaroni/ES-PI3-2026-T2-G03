// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Formatação de números do Balcão para exibição em **pt-BR** (vírgula decimal),
// alinhada ao uso de [formatBrl] na Carteira.

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
