// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Modelo **simples** para chave PIX na UI (protótipo sem Firestore).
// Usado na secção “Minhas Chaves PIX” e no fluxo de saque.

// --- Modelo -------------------------------------------------------------------

/// Uma chave PIX guardada só em memória (demonstração).
class PixChaveUi {
  const PixChaveUi({
    required this.id,
    required this.tipoLabel,
    required this.valor,
    this.apelido,
  });

  /// Identificador estável na lista (ex.: contador ou string única).
  final String id;

  /// Rótulo do tipo: E-mail, CPF, Telefone, Chave aleatória.
  final String tipoLabel;

  /// Valor literal da chave (e-mail, CPF formatado, etc.).
  final String valor;

  /// Nome opcional escolhido pelo utilizador.
  final String? apelido;

  /// Texto curto para lista e dropdown.
  String get rotuloLista {
    final a = apelido?.trim();
    if (a != null && a.isNotEmpty) return '$a · $tipoLabel';
    return '$tipoLabel · ${_mascararParaLista(valor)}';
  }
}

// --- Máscaras para exibição (privacidade) -------------------------------------

String _mascararParaLista(String v) {
  final t = v.trim();
  if (t.length <= 4) return '••••';
  if (t.contains('@')) {
    final parts = t.split('@');
    if (parts.length != 2) return '${t.substring(0, 2)}…';
    final u = parts[0];
    final d = parts[1];
    if (u.length <= 2) return '••@$d';
    return '${u.substring(0, 2)}•••@$d';
  }
  if (t.length <= 8) return '${t.substring(0, 2)}••••${t.substring(t.length - 2)}';
  return '${t.substring(0, 3)}••••${t.substring(t.length - 2)}';
}

/// Versão mais curta para o comprovante de saque.
String mascararChavePixComprovante(String v) {
  final t = v.trim();
  if (t.isEmpty) return '—';
  if (t.contains('@')) {
    final parts = t.split('@');
    if (parts.length != 2) return '•••';
    return '***@${parts[1]}';
  }
  if (t.length <= 6) return '••••••';
  return '${t.substring(0, 3)}…${t.substring(t.length - 2)}';
}
