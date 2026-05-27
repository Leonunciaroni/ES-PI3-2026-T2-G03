// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Entrada de **valores em reais** nas telas da Carteira e Balcão: máscara tipo
// “centavos por dígitos” e função para ler o texto do campo como [double].
// Extraído de [AdicionarFundosScreen] para reutilização (ex.: fluxo de saque).

import 'package:flutter/services.dart';

import 'carteira_brl.dart';

// --- Máscara enquanto o usuário digita (só dígitos → pt-BR) ----------------

/// Formata o campo enquanto digita: só **dígitos**; os dois últimos são centavos
/// (ex.: `100000` → `1.000,00`). O [parseValorReaisInput] aceita também texto já formatado.
class CentavosParaReaisInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    if (digits.length > 14) {
      return oldValue;
    }
    final centavos = int.tryParse(digits);
    if (centavos == null) {
      return oldValue;
    }
    final reais = centavos / 100.0;
    final texto = formatBrlCampo(reais);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

// --- Leitura do texto do campo como número ------------------------------------

/// Interpreta o texto do campo como valor em reais.
///
/// Formatos aceites (simples, PI):
/// - `1000` ou `1.000` (pontos como milhar, sem centavos)
/// - `1000,50` ou `1.000,50` (vírgula como separador decimal à brasileira)
/// - `1000.50` (um ponto só, tratado como decimal estilo US)
double? parseValorReaisInput(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'R\$', caseSensitive: true), '');
  s = s.replaceAll(' ', '');
  if (s.isEmpty) return null;

  if (s.contains(',')) {
    final last = s.lastIndexOf(',');
    final intPart = s.substring(0, last).replaceAll(RegExp(r'[^\d]'), '');
    var dec = s.substring(last + 1).replaceAll(RegExp(r'[^\d]'), '');
    if (dec.length > 2) dec = dec.substring(0, 2);
    if (intPart.isEmpty && dec.isEmpty) return null;
    return double.tryParse(
      '${intPart.isEmpty ? '0' : intPart}.${dec.isEmpty ? '00' : dec.padRight(2, '0')}',
    );
  }

  final limpo = s.replaceAll(RegExp(r'[^\d.]'), '');
  if (limpo.isEmpty) return null;
  final pontos = '.'.allMatches(limpo).length;
  if (pontos == 1 && RegExp(r'^\d+\.\d{1,2}$').hasMatch(limpo)) {
    return double.tryParse(limpo);
  }
  return double.tryParse(limpo.replaceAll('.', ''));
}
