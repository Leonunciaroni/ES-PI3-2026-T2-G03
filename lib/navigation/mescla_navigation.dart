// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Navegação e pré-carga (Firebase) — complemento ao tema em [app_theme.dart].
//
// ## Transições suaves entre ecrãs
// Quase todas as rotas usam [MaterialPageRoute]. O Flutter aplica então o
// [PageTransitionsTheme] definido em [buildMesclaLightTheme] /
// [buildMesclaDarkTheme]: [FadeThroughPageTransitionsBuilder] (Material 3).
// Isto dá um cruzamento fluido sem precisarmos repetir código em cada
// `Navigator.push`.
//
// ## Pré-carga durante a navegação
// O truque simples (usado em apps grandes) é: **começar** o pedido à rede ou ao
// Firestore *antes* ou *em paralelo* com a animação, e reutilizar o mesmo
// [Future] na tela de destino quando faz sentido. Assim o utilizador vê a
// transição e, quando o ecrã novo aparece, os dados já estão mais perto de
// chegar (ou já chegaram).
//
// Este módulo só agrupa funções pequenas para não espalhar essa lógica pelo app.

import 'dart:async';

import '../carteira/services/simulated_wallet_service.dart';
import '../catalog/data/startup_detail_mock.dart';
import '../catalog/models/catalog_startup.dart';
import '../catalog/services/startup_catalog_functions_service.dart';

/// Funções estáticas para “aquecer” dados antes do utilizador precisar deles.
abstract final class MesclaNavigationPrefetch {
  MesclaNavigationPrefetch._();

  /// Dispara leituras Firestore da carteira simulada **sem bloquear** a UI.
  ///
  /// Chamado tipicamente quando o utilizador muda para o separador Carteira no
  /// [DashboardScreen]. Usamos [unawaited] implicitamente pelo chamador: basta
  /// não fazer `await` deste método antes do `setState` do índice do separador.
  static void scheduleWalletFirestoreForCarteiraTab(String uid) {
    unawaited(SimulatedWalletService.prefetchWalletFirestore(uid));
  }

  /// Inicia o carregamento do detalhe da startup **antes** de empilhar a rota.
  ///
  /// Devolve `null` se não houver `firestoreId` (a [StartupDetailScreen] usa mock).
  /// O [Future] devolvido deve ser passado a [StartupDetailScreen.prefetchDetailFuture]
  /// para não haver dois pedidos duplicados ao abrir o ecrã.
  static Future<StartupDetailViewData?>? startupDetailPrefetchIfNeeded({
    required StartupCatalogFunctionsService service,
    required CatalogStartup startup,
  }) {
    final String? id = startup.firestoreId;
    if (id == null || id.isEmpty) {
      return null;
    }
    return service.fetchStartupDetail(id);
  }
}
