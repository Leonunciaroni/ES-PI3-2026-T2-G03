// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Um único pedido `listStartups()` sem filtros serve Explorar (“Todas”), Balcão e
// pré-carga ao abrir o dashboard — evita várias chamadas paralelas e listas vazias
// durante segundos ao mudar de aba.
//
// Depois dos dados regressarem com sucesso, uma tela com [BuildContext] montada
// (ex.: o dashboard inicial) pode chamar [StartupLogoPrecacheService.schedulePreloadForStartupList]
// para baixar os bitmaps dos logos antes do usuário abrir Explorar/Balcão.

import '../models/catalog_startup.dart';
import 'startup_catalog_functions_service.dart';

/// Cache em memória do catálogo completo (mesmo contrato que [StartupCatalogFunctionsService.listStartups] sem stage/search).
class StartupCatalogListCache {
  StartupCatalogListCache._();
  static final StartupCatalogListCache instance = StartupCatalogListCache._();

  Future<List<CatalogStartup>>? _inFlight;
  List<CatalogStartup>? _snapshot;

  /// Última lista bem-sucedida (útil para diagnóstico); pode ser null antes do 1.º pedido.
  List<CatalogStartup>? get snapshotIfReady => _snapshot;

  /// Compartilha o mesmo [Future] entre todas as telas até completar; depois devolve cópia instantânea.
  Future<List<CatalogStartup>> fullList(StartupCatalogFunctionsService service) {
    final List<CatalogStartup>? snap = _snapshot;
    if (snap != null) {
      return Future<List<CatalogStartup>>.value(
        List<CatalogStartup>.from(snap),
      );
    }
    _inFlight ??= service.listStartups().then((List<CatalogStartup> list) {
      _snapshot = list;
      return list;
    });
    return _inFlight!;
  }

  /// Inicia o pedido cedo (ex.: [DashboardScreen.initState]) para sobrepor latência de rede.
  void prefetch(StartupCatalogFunctionsService service) {
    fullList(service);
  }

  /// Limpa estado (ex.: após logout); próximo acesso volta a ir ao servidor.
  void clear() {
    _inFlight = null;
    _snapshot = null;
  }
}
