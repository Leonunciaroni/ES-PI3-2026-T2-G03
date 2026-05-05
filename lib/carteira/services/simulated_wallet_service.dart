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

  /// Débito de saldo (saque simulado) e linha no ledger `withdraw_pix_simulated`.
  static Future<void> withdrawPixSimulated({
    required double amountBrl,
    required String pixTipoLabel,
    required String pixDestHint,
  }) async {
    await _fn().httpsCallable('simulateWallet').call(<String, dynamic>{
      'action': 'withdraw_pix_simulated',
      'amountBrl': amountBrl,
      'pixTipo': pixTipoLabel,
      'pixDestHint': pixDestHint,
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

  /// Quantidade atual de tokens numa startup (0 se sem posição).
  static Stream<double> watchTokensHeld(
    String uid,
    String startupFirestoreId,
  ) {
    return SimulatedWalletPaths.positionsCol(uid)
        .doc(startupFirestoreId)
        .snapshots()
        .map((snapshot) {
      final dynamic t = snapshot.data()?['tokensHeld'];
      if (t is num) {
        return t.toDouble();
      }
      return 0.0;
    });
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

  /// Pré-carga da carteira simulada no Firestore.
  ///
  /// Objetivo pedagógico e de UX: disparar **em paralelo** com a navegação (ex.: ao
  /// tocar no separador “Carteira”) para que o SDK já traga documentos para a cache
  /// local antes dos [StreamBuilder]s da [CarteiraScreen] subscreverem `snapshots()`.
  ///
  /// Não é obrigatório chamar — a tela funciona sem isto — mas reduz a sensação de
  /// “ficar à espera” no primeiro frame. Erros (offline, permissões) são ignorados
  /// aqui; a própria tela mostra estado de erro.
  static Future<void> prefetchWalletFirestore(String uid) async {
    try {
      final DocumentReference<Map<String, dynamic>> doc =
          SimulatedWalletPaths.walletDoc(uid);
      final CollectionReference<Map<String, dynamic>> ledger =
          SimulatedWalletPaths.ledgerCol(uid);
      final CollectionReference<Map<String, dynamic>> positions =
          SimulatedWalletPaths.positionsCol(uid);

      const GetOptions opts = GetOptions(source: Source.serverAndCache);

      await Future.wait<Object?>(<Future<Object?>>[
        doc.get(opts),
        ledger.orderBy('createdAt', descending: true).limit(500).get(opts),
        positions.get(opts),
      ]);
    } catch (_) {
      // Ver doc acima: falhas não bloqueiam navegação.
    }
  }

  static String messageForUser(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'not-found':
          return 'Serviço de carteira indisponível. Se usa o emulador, confirme '
              '`firebase emulators:start` e `--dart-define=USE_FUNCTIONS_EMULATOR=true`. '
              'Em produção, faça deploy da função simulateWallet.';
        case 'unauthenticated':
          return 'Faça login novamente para usar a carteira.';
        case 'failed-precondition':
          final msg = error.message ?? '';
          if (msg.contains('não conferem') ||
              msg.contains('nao conferem')) {
            return 'A cotação no servidor atualizou-se. Volte ao Balcão e confira o valor total antes de repetir.';
          }
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
