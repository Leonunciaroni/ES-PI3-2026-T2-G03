// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Service do Order Book — streams Firestore (leitura) e callables (escrita).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/compra_ordem_result.dart';
import '../models/ordem_model.dart';

/// Caminhos Firestore da coleção `orders`.
abstract final class BalcaoOrderPaths {
  BalcaoOrderPaths._();

  static const String root = 'orders';
  static const String userOpenOrdersSubcol = 'balcao_ordens_abertas';

  static DocumentReference<Map<String, dynamic>> startupDoc(String startupId) =>
      FirebaseFirestore.instance.collection(root).doc(startupId);

  static CollectionReference<Map<String, dynamic>> sellCol(String startupId) =>
      startupDoc(startupId).collection('sell');

  static CollectionReference<Map<String, dynamic>> buyCol(String startupId) =>
      startupDoc(startupId).collection('buy');
}

/// Operações do livro de ordens P2P no Balcão.
///
/// Leitura direta no Firestore (regras permitem read autenticado).
/// Escrita exclusivamente via Cloud Functions callable.
abstract final class BalcaoOrderService {
  BalcaoOrderService._();

  static FirebaseFunctions _fn() =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Stream de ordens de **venda** abertas de uma startup.
  ///
  /// Ordenação final no cliente via [bubbleSortOrdens].
  static Stream<List<OrdemModel>> watchSellOrders(String startupId) {
    final id = startupId.trim();
    if (id.isEmpty) {
      return Stream<List<OrdemModel>>.value(const <OrdemModel>[]);
    }
    return BalcaoOrderPaths.sellCol(id)
        .where('status', isEqualTo: StatusOrdem.aberta.firestoreValue)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map(
            (doc) => OrdemModel.fromFirestore(
              doc: doc,
              tipo: TipoOrdem.venda,
            ),
          )
          .toList();
    });
  }

  /// Stream de ordens de **compra** abertas de uma startup.
  static Stream<List<OrdemModel>> watchBuyOrders(String startupId) {
    final id = startupId.trim();
    if (id.isEmpty) {
      return Stream<List<OrdemModel>>.value(const <OrdemModel>[]);
    }
    return BalcaoOrderPaths.buyCol(id)
        .where('status', isEqualTo: StatusOrdem.aberta.firestoreValue)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map(
            (doc) => OrdemModel.fromFirestore(
              doc: doc,
              tipo: TipoOrdem.compra,
            ),
          )
          .toList();
    });
  }

  /// Stream das ordens **abertas** do utilizador.
  ///
  /// Lê o espelho em `users/{uid}/balcao_ordens_abertas` (escrito pelas Functions).
  static Stream<List<OrdemModel>> watchMinhasOrdens(String uid) {
    final u = uid.trim();
    if (u.isEmpty) {
      return Stream<List<OrdemModel>>.value(const <OrdemModel>[]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(u)
        .collection(BalcaoOrderPaths.userOpenOrdersSubcol)
        .where('uid', isEqualTo: u)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => OrdemModel.fromUserOpenIndex(doc))
              .where((ordem) => ordem.uid == u)
              .toList(),
        );
  }

  /// Sincroniza espelho de ordens abertas (ordens criadas antes do deploy).
  static Future<int> sincronizarMinhasOrdens() async {
    final result =
        await _fn().httpsCallable('backfillMyOpenOrders').call<Object?>(null);
    final data = result.data;
    if (data is Map) {
      final synced = data['synced'];
      if (synced is int) return synced;
      if (synced is num) return synced.round();
    }
    return 0;
  }

  /// Publica ordem de venda — callable `addSellOrder`.
  static Future<void> criarOrdemVenda({
    required String startupId,
    required int quantity,
    required double pricePerToken,
  }) async {
    await _fn().httpsCallable('addSellOrder').call(<String, dynamic>{
      'startupId': startupId.trim(),
      'quantity': quantity,
      'pricePerToken': pricePerToken,
    });
  }

  /// Publica ordem de compra — callable `addBuyOrder`.
  ///
  /// Com [targetSellOrderId], executa compra directa da oferta de venda indicada.
  static Future<CompraOrdemResult> criarOrdemCompra({
    required String startupId,
    required int quantity,
    required double pricePerToken,
    String? targetSellOrderId,
  }) async {
    final payload = <String, dynamic>{
      'startupId': startupId.trim(),
      'quantity': quantity,
      'pricePerToken': pricePerToken,
    };
    final sellId = targetSellOrderId?.trim() ?? '';
    if (sellId.isNotEmpty) {
      payload['targetSellOrderId'] = sellId;
    }

    final result = await _fn().httpsCallable('addBuyOrder').call(payload);
    final data = result.data;
    if (data is! Map) {
      throw StateError('Resposta inválida do servidor.');
    }

    final map = Map<String, dynamic>.from(data);
    return CompraOrdemResult(
      matched: map['matched'] == true,
      quantity: _parseInt(map['quantity']) ?? quantity,
      amountBrl: _parseDouble(map['amountBrl']) ??
          (quantity * pricePerToken),
      pricePerToken: _parseDouble(map['pricePerToken']) ?? pricePerToken,
      startupName: map['startupName'] as String? ?? '',
      tokenSigla: map['tokenSigla'] as String? ?? '',
    );
  }

  static int? _parseInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return null;
  }

  static double? _parseDouble(Object? v) {
    if (v is num) return v.toDouble();
    return null;
  }

  /// Cancela ordem aberta — callable `cancelOrder`.
  static Future<void> cancelarOrdem({
    required String startupId,
    required String orderId,
    required String tipo,
  }) async {
    await _fn().httpsCallable('cancelOrder').call(<String, dynamic>{
      'startupId': startupId.trim(),
      'orderId': orderId.trim(),
      'tipo': tipo.trim().toLowerCase(),
    });
  }

  /// Edita quantidade e preço de ordem aberta — callable `editOrder`.
  static Future<void> editarOrdem({
    required String startupId,
    required String orderId,
    required String tipo,
    required int quantity,
    required double pricePerToken,
  }) async {
    await _fn().httpsCallable('editOrder').call(<String, dynamic>{
      'startupId': startupId.trim(),
      'orderId': orderId.trim(),
      'tipo': tipo.trim().toLowerCase(),
      'quantity': quantity,
      'pricePerToken': pricePerToken,
    });
  }

  /// Converte exceções das Functions em mensagens amigáveis para SnackBar.
  static String messageForUser(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Faça login novamente para usar o Order Book.';
        case 'failed-precondition':
          return error.message ?? 'Condição não atendida.';
        case 'invalid-argument':
          return error.message ?? 'Dados inválidos.';
        case 'not-found':
          return error.message ?? 'Ordem ou startup não encontrada.';
        case 'permission-denied':
          return error.message ?? 'Sem permissão para esta operação.';
        case 'unavailable':
          return 'Não foi possível contactar as Cloud Functions. '
              'Confirme o deploy das funções do Balcão.';
        case 'internal':
          return error.message?.trim().isNotEmpty == true
              ? error.message!
              : 'Erro interno no servidor. Confirme o deploy das funções '
                  '(addBuyOrder) e os índices Firestore do Order Book.';
        default:
          return error.message ?? 'Não foi possível concluir a operação.';
      }
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Não foi possível concluir a operação.';
  }
}
