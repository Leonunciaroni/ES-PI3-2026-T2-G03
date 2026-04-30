// Carteira: créditos e negócios via Cloud Function [simulateWallet];
// leitura de saldo, extrato e posições via Firestore [sim_wallet].

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../catalog/models/catalog_startup.dart';

abstract final class SimulatedWalletPaths {
  SimulatedWalletPaths._();

  static const String root = 'sim_wallet';

  static DocumentReference<Map<String, dynamic>> walletDoc(String uid) =>
      FirebaseFirestore.instance.collection(root).doc(uid);

  static CollectionReference<Map<String, dynamic>> ledgerCol(String uid) =>
      walletDoc(uid).collection('ledger');

  static CollectionReference<Map<String, dynamic>> positionsCol(String uid) =>
      walletDoc(uid).collection('positions');
}

abstract final class SimulatedWalletService {
  SimulatedWalletService._();

  static FirebaseFunctions _fn() =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Crédito após o fluxo PIX (atribuído no cliente após o temporizador).
  static Future<void> creditPixSimulated({required double amountBrl}) async {
    await _fn().httpsCallable('simulateWallet').call(<String, dynamic>{
      'action': 'credit_pix_simulated',
      'amountBrl': amountBrl,
      'headline': 'Crédito PIX',
    });
  }

  static Future<void> tradeBuy({
    required CatalogStartup startup,
    required double valorReais,
    required double quantidadeTokens,
  }) async {
    final id = startup.firestoreId;
    if (id == null || id.isEmpty) {
      throw StateError('Startup sem identificador Firestore.');
    }
    if (startup.tokenPrice <= 0) {
      throw StateError('Cotação do token indisponível.');
    }
    await _fn().httpsCallable('simulateWallet').call(<String, dynamic>{
      'action': 'trade_buy',
      'amountBrl': valorReais,
      'tokens': quantidadeTokens,
      'startupId': id,
      'startupName': startup.name,
      'tokenSigla': _siglaOuAbrev(startup),
      'category': startup.category,
    });
  }

  static Future<void> tradeSell({
    required CatalogStartup startup,
    required double valorReais,
    required double quantidadeTokens,
  }) async {
    final id = startup.firestoreId;
    if (id == null || id.isEmpty) {
      throw StateError('Startup sem identificador Firestore.');
    }
    if (startup.tokenPrice <= 0) {
      throw StateError('Cotação do token indisponível.');
    }
    await _fn().httpsCallable('simulateWallet').call(<String, dynamic>{
      'action': 'trade_sell',
      'amountBrl': valorReais,
      'tokens': quantidadeTokens,
      'startupId': id,
      'startupName': startup.name,
      'tokenSigla': _siglaOuAbrev(startup),
      'category': startup.category,
    });
  }

  static String _siglaOuAbrev(CatalogStartup s) {
    final raw = s.sigla?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw.toUpperCase();
    }
    final n = s.name.trim();
    if (n.length <= 5) return n.toUpperCase();
    return '${n.substring(0, 4).toUpperCase()}…';
  }

  /// Saldo bruto em reais disponível para novas compras (stream).
  static Stream<double> watchBrlBalance(String uid) {
    return SimulatedWalletPaths.walletDoc(uid).snapshots().map((s) {
      final v = s.data()?['brlBalance'];
      return v is num ? v.toDouble() : 0.0;
    });
  }

  /// Últimos movimentos ordenados por data.
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchLedger(
    String uid, {
    int limit = 28,
  }) {
    return SimulatedWalletPaths.ledgerCol(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Movimentos mais recentes (limite [limit]) — ordenar no cliente de forma
  /// ascendente para gráficos ou agregações no tempo.
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchLedgerRecentForChart(
    String uid, {
    int limit = 500,
  }) {
    return SimulatedWalletPaths.ledgerCol(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Posições atuais (tokens por startup).
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchPositions(
    String uid,
  ) {
    return SimulatedWalletPaths.positionsCol(uid).snapshots();
  }

  static Future<double?> fetchTokensHeld(
    String uid,
    String startupFirestoreId,
  ) async {
    final snap = await SimulatedWalletPaths.positionsCol(uid)
        .doc(startupFirestoreId)
        .get();
    final t = snap.data()?['tokensHeld'];
    if (t is num) {
      return t.toDouble();
    }
    return null;
  }

  static Future<double> fetchBrlBalance(String uid) async {
    final s = await SimulatedWalletPaths.walletDoc(uid).get();
    final v = s.data()?['brlBalance'];
    return v is num ? v.toDouble() : 0.0;
  }

  static String messageForUser(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'not-found':
          final detail = error.message?.trim();
          if (detail != null && detail.isNotEmpty) {
            return detail;
          }
          return 'Serviço de carteira indisponível. Se usa o emulador, confirme '
              '`firebase emulators:start` e `--dart-define=USE_FUNCTIONS_EMULATOR=true`. '
              'Em produção, faça deploy da função simulateWallet.';
        case 'unauthenticated':
          return 'Faça login novamente para usar a carteira.';
        case 'failed-precondition':
          return error.message ?? 'Condição não atendida.';
        case 'invalid-argument':
          return error.message ?? 'Dados inválidos.';
        case 'unavailable':
          return 'Não foi possível contactar as Cloud Functions. Com emulador, '
              'confirme que está a correr na porta 5001 e faça um rebuild '
              'completo da app (Android: tráfego HTTP ao emulador).';
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
