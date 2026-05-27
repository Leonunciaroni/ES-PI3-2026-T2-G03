// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Formatação BR compartilhada pelas telas da Carteira (saldo, adicionar fundos, PIX).

/// Formata um valor em reais no estilo brasileiro: `R$ 12.450,00`.
///
/// Não usamos [NumberFormat] para evitar dependência extra; o algoritmo é
/// explícito: parte inteira com milhares separados por ponto e centavos com vírgula.
String formatBrl(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  var intPart = parts[0];
  final dec = parts[1];
  final reversed = intPart.split('').reversed.join();
  final withDots = StringBuffer();
  for (var i = 0; i < reversed.length; i++) {
    if (i > 0 && i % 3 == 0) withDots.write('.');
    withDots.write(reversed[i]);
  }
  intPart = withDots.toString().split('').reversed.join();
  return 'R\$ $intPart,$dec';
}

/// Mesmo formato que [formatBrl], sem o prefixo `R$ ` — para o texto do campo.
///
/// Ex.: `1234.5` → `1.234,50`.
String formatBrlCampo(double value) {
  return formatBrl(value).replaceFirst(RegExp(r'^R\$\s*'), '');
}
