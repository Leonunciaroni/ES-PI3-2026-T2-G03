// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Lê a cotação oficial (`preco_token`) em `startups/{id}` — mesma fonte que
// `simulateWallet` no backend — para revalidar a ordem antes da callable.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../catalog/services/startup_firestore_schema.dart';

/// Retorna o preço em BRL por token, ou `null` se ausente / inválido / doc inexistente.
Future<double?> fetchPrecoTokenOficialBrl(String startupFirestoreId) async {
  final id = startupFirestoreId.trim();
  if (id.isEmpty) return null;
  final snap = await FirebaseFirestore.instance
      .collection(kFirestoreStartupsCollection)
      .doc(id)
      .get();
  if (!snap.exists) return null;
  final raw = snap.data()?[kFieldPrecoToken];
  if (raw is num) {
    final v = raw.toDouble();
    return v.isFinite && v > 0 ? v : null;
  }
  if (raw is String) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (v == null || !v.isFinite || v <= 0) return null;
    return v;
  }
  return null;
}
