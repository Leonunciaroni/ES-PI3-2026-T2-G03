// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
// Descrição: Service do Order Book — streams Firestore (leitura) e callables (escrita).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/ordem_model.dart';

/// Caminhos Firestore da coleção `orders`.
abstract final class BalcaoOrderPaths {
  BalcaoOrderPaths._();

  static const String root = 'orders';

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

  /// Stream das ordens **abertas** do utilizador em todas as startups.
  ///
  /// Usa collection group queries em `sell` e `buy` (índice composto pode ser
  /// solicitado pelo Firebase Console na primeira execução).
  static Stream<List<OrdemModel>> watchMinhasOrdens(String uid) {
    final u = uid.trim();
    if (u.isEmpty) {
      return Stream<List<OrdemModel>>.value(const <OrdemModel>[]);
    }

    final controller = StreamController<List<OrdemModel>>.broadcast();
    List<OrdemModel> vendas = const <OrdemModel>[];
    List<OrdemModel> compras = const <OrdemModel>[];

    void emitMerged() {
      final todas = <OrdemModel>[...vendas, ...compras];
      todas.sort((a, b) {
        final ta = a.createdAt;
        final tb = b.createdAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      if (!controller.isClosed) {
        controller.add(todas);
      }
    }

    final sellSub = FirebaseFirestore.instance
        .collectionGroup('sell')
        .where('uid', isEqualTo: u)
        .where('status', isEqualTo: StatusOrdem.aberta.firestoreValue)
        .snapshots()
        .listen(
      (snap) {
        vendas = snap.docs
            .map(
              (doc) => OrdemModel.fromFirestore(
                doc: doc,
                tipo: TipoOrdem.venda,
              ),
            )
            .toList();
        emitMerged();
      },
      onError: controller.addError,
    );

    final buySub = FirebaseFirestore.instance
        .collectionGroup('buy')
        .where('uid', isEqualTo: u)
        .where('status', isEqualTo: StatusOrdem.aberta.firestoreValue)
        .snapshots()
        .listen(
      (snap) {
        compras = snap.docs
            .map(
              (doc) => OrdemModel.fromFirestore(
                doc: doc,
                tipo: TipoOrdem.compra,
              ),
            )
            .toList();
        emitMerged();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await sellSub.cancel();
      await buySub.cancel();
    };

    return controller.stream;
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
  static Future<void> criarOrdemCompra({
    required String startupId,
    required int quantity,
    required double pricePerToken,
  }) async {
    await _fn().httpsCallable('addBuyOrder').call(<String, dynamic>{
      'startupId': startupId.trim(),
      'quantity': quantity,
      'pricePerToken': pricePerToken,
    });
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
