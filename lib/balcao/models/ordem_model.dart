// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Modelo de ordem do Order Book P2P — espelho do contrato Firestore/backend.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Lado da ordem no livro: compra ou venda.
enum TipoOrdem {
  /// Ordem de compra — subcoleção `buy`.
  compra('buy'),

  /// Ordem de venda — subcoleção `sell`.
  venda('sell');

  const TipoOrdem(this.firestoreValue);

  /// Valor gravado no Firestore e enviado às Cloud Functions.
  final String firestoreValue;

  /// Converte string do backend (`buy` / `sell`) para enum.
  static TipoOrdem? fromFirestoreValue(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    for (final t in TipoOrdem.values) {
      if (t.firestoreValue == v) return t;
    }
    return null;
  }
}

/// Estado da ordem no livro.
enum StatusOrdem {
  /// Ordem ativa aguardando contraparte.
  aberta('open'),

  /// Ordem cancelada pelo investidor.
  cancelada('cancelled'),

  /// Ordem totalmente executada.
  executada('completed');

  const StatusOrdem(this.firestoreValue);

  final String firestoreValue;

  static StatusOrdem? fromFirestoreValue(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    for (final s in StatusOrdem.values) {
      if (s.firestoreValue == v) return s;
    }
    return null;
  }
}

/// Representa uma ordem aberta ou histórica no Order Book de uma startup.
class OrdemModel {
  const OrdemModel({
    required this.orderId,
    required this.tipo,
    required this.uid,
    required this.displayName,
    required this.startupId,
    required this.startupName,
    required this.tokenSigla,
    required this.quantity,
    required this.pricePerToken,
    required this.sortKey,
    required this.status,
    required this.createdAt,
  });

  /// ID do documento Firestore (`sell/{orderId}` ou `buy/{orderId}`).
  final String orderId;

  final TipoOrdem tipo;
  final String uid;
  final String displayName;
  final String startupId;
  final String startupName;
  final String tokenSigla;

  /// Quantidade de tokens — sempre inteiro.
  final int quantity;

  final double pricePerToken;

  /// Chave de ordenação calculada no backend (nunca no cliente).
  final double sortKey;

  final StatusOrdem status;
  final DateTime? createdAt;

  /// Valor total estimado da ordem em BRL.
  double get totalValueBrl => quantity * pricePerToken;

  /// Indica se a ordem ainda pode ser cancelada.
  bool get podeCancelar => status == StatusOrdem.aberta;

  /// Mapeia documento Firestore para [OrdemModel].
  ///
  /// [tipo] deve ser informado porque a subcoleção (`sell` ou `buy`) não vem no doc.
  factory OrdemModel.fromFirestore({
    required DocumentSnapshot<Map<String, dynamic>> doc,
    required TipoOrdem tipo,
  }) {
    final data = doc.data() ?? <String, dynamic>{};

    final qtyRaw = data['quantity'];
    final quantity = qtyRaw is int
        ? qtyRaw
        : qtyRaw is num
            ? qtyRaw.round()
            : 0;

    final priceRaw = data['pricePerToken'];
    final sortRaw = data['sortKey'];

    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    }

    return OrdemModel(
      orderId: doc.id,
      tipo: tipo,
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '—',
      startupId: data['startupId'] as String? ?? '',
      startupName: data['startupName'] as String? ?? '',
      tokenSigla: data['tokenSigla'] as String? ?? '',
      quantity: quantity,
      pricePerToken: priceRaw is num ? priceRaw.toDouble() : 0.0,
      sortKey: sortRaw is num ? sortRaw.toDouble() : 0.0,
      status: StatusOrdem.fromFirestoreValue(data['status'] as String?) ??
          StatusOrdem.aberta,
      createdAt: createdAt,
    );
  }

  /// Payload mínimo para callables (campos editáveis pelo cliente).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'startupId': startupId,
      'quantity': quantity,
      'pricePerToken': pricePerToken,
    };
  }

  OrdemModel copyWith({
    String? orderId,
    TipoOrdem? tipo,
    String? uid,
    String? displayName,
    String? startupId,
    String? startupName,
    String? tokenSigla,
    int? quantity,
    double? pricePerToken,
    double? sortKey,
    StatusOrdem? status,
    DateTime? createdAt,
  }) {
    return OrdemModel(
      orderId: orderId ?? this.orderId,
      tipo: tipo ?? this.tipo,
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      startupId: startupId ?? this.startupId,
      startupName: startupName ?? this.startupName,
      tokenSigla: tokenSigla ?? this.tokenSigla,
      quantity: quantity ?? this.quantity,
      pricePerToken: pricePerToken ?? this.pricePerToken,
      sortKey: sortKey ?? this.sortKey,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
