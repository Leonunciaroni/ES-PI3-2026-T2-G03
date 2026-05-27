// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Modelo de **chave PIX** na UI e no Firestore (`users/{uid}.chavesPix[]`).
// Cada entrada no array é um mapa com [kFirestoreTipo], [kFirestoreValor],
// [kFirestoreApelido] e [kFirestoreId].

// --- Chaves usadas no documento `users` (Cloud Firestore) ---------------------

/// Nome do campo no mapa gravado em `users/{uid}.chavesPix`.
const String kFirestorePixId = 'id';
const String kFirestorePixTipo = 'tipo';
const String kFirestorePixValor = 'valor';
const String kFirestorePixApelido = 'apelido';

// --- Modelo -------------------------------------------------------------------

/// Uma chave PIX (memória local ou sincronizada com Firestore).
class PixChaveUi {
  const PixChaveUi({
    required this.id,
    required this.tipoLabel,
    required this.valor,
    this.apelido,
  });

  /// Identificador estável na lista (gerado na app; necessário para editar/apagar).
  final String id;

  /// Rótulo do tipo: E-mail, CPF, Telefone, Chave aleatória.
  final String tipoLabel;

  /// Valor persistido: CPF/telefone só dígitos; e-mail em minúsculas; EVP/UUID como texto.
  final String valor;

  /// Nome opcional escolhido pelo usuário.
  final String? apelido;

  /// Mapa gravado em `users/{uid}` — sem tipos aninhados, só primitivos.
  Map<String, dynamic> toFirestoreMap() {
    final m = <String, dynamic>{
      kFirestorePixId: id,
      kFirestorePixTipo: tipoLabel,
      kFirestorePixValor: valor,
    };
    final a = apelido?.trim();
    if (a != null && a.isNotEmpty) {
      m[kFirestorePixApelido] = a;
    }
    return m;
  }

  /// Lê um elemento do array [chavesPix] do Firestore; devolve `null` se inválido.
  static PixChaveUi? tryFromFirestore(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = (m[kFirestorePixId] ?? m['id'])?.toString().trim() ?? '';
    final tipo = (m[kFirestorePixTipo] ?? m['tipo'])?.toString().trim() ?? '';
    final valor = (m[kFirestorePixValor] ?? m['valor'])?.toString().trim() ?? '';
    if (id.isEmpty || tipo.isEmpty || valor.isEmpty) return null;
    final apRaw = m[kFirestorePixApelido] ?? m['apelido'];
    final ap = apRaw is String ? apRaw.trim() : '';
    return PixChaveUi(
      id: id,
      tipoLabel: tipo,
      valor: valor,
      apelido: ap.isEmpty ? null : ap,
    );
  }

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
