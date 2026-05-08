// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Formatação **visual** (máscara ao digitar) e validação de chaves PIX na UI.
// Valores persistidos: CPF e telefone só com dígitos; e-mail em minúsculas;
// chave aleatória sem alteração de formato além de trim.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pix_chave_ui.dart';

/// Só dígitos, no máximo [max].
String somenteDigitos(String s, {int? max}) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (c.compareTo('0') >= 0 && c.compareTo('9') <= 0) {
      b.write(c);
      if (max != null && b.length >= max) break;
    }
  }
  return b.toString();
}

/// Ex.: `54262229831` → `542.622.298-31`
String formatarCpfVisual(String digitos) {
  final d = somenteDigitos(digitos, max: 11);
  if (d.isEmpty) return '';
  if (d.length <= 3) return d;
  if (d.length <= 6) return '${d.substring(0, 3)}.${d.substring(3)}';
  if (d.length <= 9) {
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6)}';
  }
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
}

/// Celular BR: `(19) 98708-7013` — 11 dígitos (DDD + 9).
String formatarTelefoneCelularVisual(String digitos) {
  final d = somenteDigitos(digitos, max: 11);
  if (d.isEmpty) return '';
  if (d.length <= 2) return '($d';
  final ddd = d.substring(0, 2);
  final rest = d.substring(2);
  if (rest.isEmpty) return '($ddd)';
  if (rest.length <= 5) return '($ddd) $rest';
  return '($ddd) ${rest.substring(0, 5)}-${rest.substring(5)}';
}

/// Texto inicial do campo ao abrir edição (Firestore pode ter só dígitos).
String textoInicialCampoChavePix(String tipoLabel, String valorArmazenado) {
  final raw = valorArmazenado.trim();
  if (raw.isEmpty) return '';
  switch (tipoLabel) {
    case 'CPF':
      return formatarCpfVisual(raw);
    case 'Telefone':
      final d = somenteDigitos(raw, max: 11);
      return formatarTelefoneCelularVisual(d);
    default:
      return raw;
  }
}

/// Valor a gravar em `chavesPix[].valor` (sem máscara visual).
String pixValorParaPersistencia(String tipoLabel, String textoCampo) {
  final t = textoCampo.trim();
  switch (tipoLabel) {
    case 'CPF':
      return somenteDigitos(t, max: 11);
    case 'Telefone':
      return somenteDigitos(t, max: 11);
    case 'E-mail':
      return t.toLowerCase();
    default:
      return t;
  }
}

/// Texto formatado para listas (valor já normalizado no armazenamento).
String pixChaveValorExibicao(String tipoLabel, String valorArmazenado) {
  final v = valorArmazenado.trim();
  if (v.isEmpty) return v;
  switch (tipoLabel) {
    case 'CPF':
      final d = somenteDigitos(v, max: 11);
      if (d.length == 11) return formatarCpfVisual(d);
      return v;
    case 'Telefone':
      final d = somenteDigitos(v, max: 11);
      if (d.length == 11) return formatarTelefoneCelularVisual(d);
      return v;
    default:
      return v;
  }
}

bool _cpfDigitosValidos(String d) {
  if (d.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
  var soma = 0;
  for (var i = 0; i < 9; i++) {
    soma += int.parse(d[i]) * (10 - i);
  }
  var r = (soma * 10) % 11;
  if (r == 10) r = 0;
  if (r != int.parse(d[9])) return false;
  soma = 0;
  for (var i = 0; i < 10; i++) {
    soma += int.parse(d[i]) * (11 - i);
  }
  r = (soma * 10) % 11;
  if (r == 10) r = 0;
  return r == int.parse(d[10]);
}

final RegExp _emailBasico = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

bool _evpOuUuidValido(String s) {
  final t = s.replaceAll(RegExp(r'\s'), '');
  if (t.length == 32 && RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(t)) return true;
  if (t.length == 36) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(t);
  }
  return false;
}

/// `null` se válido; senão mensagem para [SnackBar] ou [InputDecoration.errorText].
String? mensagemErroValidacaoPixChave(String tipoLabel, String textoCampo) {
  final v = textoCampo.trim();
  if (v.isEmpty) return 'Informe a chave.';
  switch (tipoLabel) {
    case 'CPF':
      final d = somenteDigitos(v, max: 11);
      if (d.length != 11) return 'O CPF deve ter 11 dígitos.';
      if (!_cpfDigitosValidos(d)) return 'CPF inválido (dígitos verificadores).';
      return null;
    case 'Telefone':
      final d = somenteDigitos(v, max: 11);
      if (d.length != 11) {
        return 'O telefone deve ter 11 dígitos (DDD + celular com 9).';
      }
      if (d[2] != '9') {
        return 'Use o celular com 9 após o DDD (ex.: (19) 98708-7013).';
      }
      return null;
    case 'E-mail':
      if (v.length > 254) return 'E-mail demasiado longo (máx. 254 caracteres).';
      if (!_emailBasico.hasMatch(v)) return 'E-mail inválido.';
      return null;
    case 'Chave aleatória':
      if (v.length > 36) {
        return 'Chave aleatória demasiado longa (máx. 36 caracteres).';
      }
      if (!_evpOuUuidValido(v)) {
        return 'Chave aleatória inválida (use EVP 32 hex ou UUID).';
      }
      return null;
    default:
      return 'Tipo de chave desconhecido.';
  }
}

const int kPixCpfCampoMaxLength = 14;
const int kPixTelefoneCampoMaxLength = 15;
const int kPixEmailCampoMaxLength = 254;
const int kPixAleatoriaCampoMaxLength = 36;

/// Máscara CPF ao digitar; mantém no máximo 11 dígitos.
class CpfPixInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = somenteDigitos(newValue.text, max: 11);
    final f = formatarCpfVisual(d);
    return TextEditingValue(
      text: f,
      selection: TextSelection.collapsed(offset: f.length),
    );
  }
}

/// Máscara telefone celular BR ao digitar.
class TelefoneCelularPixInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = somenteDigitos(newValue.text, max: 11);
    final f = formatarTelefoneCelularVisual(d);
    return TextEditingValue(
      text: f,
      selection: TextSelection.collapsed(offset: f.length),
    );
  }
}

String _hintChavePix(String tipoLabel) {
  switch (tipoLabel) {
    case 'CPF':
      return '000.000.000-00';
    case 'Telefone':
      return '(00) 00000-0000';
    case 'E-mail':
      return 'nome@exemplo.com';
    case 'Chave aleatória':
      return 'EVP (32 hex) ou UUID';
    default:
      return '';
  }
}

/// Campo “Chave” do diálogo PIX: máscara, teclado e limite de caracteres por tipo.
class PixChaveValorTextField extends StatelessWidget {
  const PixChaveValorTextField({
    super.key,
    required this.tipoLabel,
    required this.controller,
  });

  final String tipoLabel;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    switch (tipoLabel) {
      case 'CPF':
        return TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [CpfPixInputFormatter()],
          maxLength: kPixCpfCampoMaxLength,
          decoration: InputDecoration(
            labelText: 'Chave',
            hintText: _hintChavePix(tipoLabel),
            counterText: '',
          ),
        );
      case 'Telefone':
        return TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [TelefoneCelularPixInputFormatter()],
          maxLength: kPixTelefoneCampoMaxLength,
          decoration: InputDecoration(
            labelText: 'Chave',
            hintText: _hintChavePix(tipoLabel),
            counterText: '',
          ),
        );
      case 'E-mail':
        return TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          maxLength: kPixEmailCampoMaxLength,
          decoration: InputDecoration(
            labelText: 'Chave',
            hintText: _hintChavePix(tipoLabel),
            counterText: '',
          ),
        );
      case 'Chave aleatória':
        return TextField(
          controller: controller,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          maxLength: kPixAleatoriaCampoMaxLength,
          decoration: InputDecoration(
            labelText: 'Chave',
            hintText: _hintChavePix(tipoLabel),
            counterText: '',
          ),
        );
      default:
        return TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Chave'),
        );
    }
  }
}

/// CPF/telefone com máscara para listas; importe este ficheiro para usar o getter.
extension PixChaveUiFormatacao on PixChaveUi {
  String get valorParaListagem => pixChaveValorExibicao(tipoLabel, valor);
}
