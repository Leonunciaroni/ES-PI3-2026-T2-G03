// ============================================================
// ARQUIVO: favoritos_screen.dart
// AUTOR PRINCIPAL: Miguel Costacurta - 25003110
// ============================================================
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ MIGUEL — O QUE VOCÊ FEZ (lista de favoritos / lista de desejos)          │
// │                                                                          │
// │ Esta tela mostra as startups que o usuário favoritou.                    │
// │ Abre a partir do Perfil → "Lista de Desejos".                            │
// │                                                                          │
// │ FLUXO RESUMIDO:                                                          │
// │   1. Firestore emite IDs: users/{uid}.favoriteStartupIds                 │
// │   2. Busca dados completos das startups (catálogo em cache/Function)     │
// │   3. Cruza IDs com catálogo → monta lista de CatalogStartup              │
// │   4. Renderiza cards iguais ao Explorar                                  │
// │                                                                          │
// │ CAMINHO DE ESTUDO:                                                       │
// │   1. Este arquivo (FavoritosScreen)                                      │
// │   2. startup_detail_screen.dart → _toggleWishlist (marcar/desmarcar)     │
// │   3. startup_detail_screen_widgets.dart → botão "Lista de Desejos"       │
// │   4. user_firestore_service.dart → watch/set favoriteStartupIds (Pedro)  │
// └──────────────────────────────────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/services/user_firestore_service.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../catalog/services/startup_catalog_functions_service.dart';
import '../../catalog/services/startup_catalog_list_cache.dart';
import '../../catalog/services/startup_logo_precache_service.dart';
import '../../catalog/widgets/catalog_startup_card.dart';
import '../../catalog/widgets/mescla_detail_header.dart';
import '../../theme/app_colors.dart';

/// Ecrã dedicado à lista de desejos (aberto a partir do Perfil).
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key, this.onInvestir});

  /// Callback repassado ao card: ao investir, o Dashboard troca para o Balcão.
  final void Function(CatalogStartup)? onInvestir;

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  // Serviço que busca startups via Cloud Function listStartups.
  late final StartupCatalogFunctionsService _functionsService;

  // Stream que combina IDs do Firestore + resolução para objetos completos.
  late final Stream<List<CatalogStartup>> _favoritesStream;

  @override
  void initState() {
    super.initState();
    _functionsService = StartupCatalogFunctionsService();

    // watchFavoriteStartupIds() emite sempre que favoriteStartupIds muda no Firestore.
    // asyncMap chama _resolveFavorites para transformar IDs em CatalogStartup.
    _favoritesStream = UserFirestoreService.watchFavoriteStartupIds().asyncMap(
      _resolveFavorites,
    );
  }

  /// Converte lista de IDs (Firestore) em lista de startups com nome, logo, etc.
  ///
  /// Por quê não guardar a startup inteira no Firestore?
  /// → Só guardamos IDs; os dados vêm do catálogo (fonte única, sempre atualizada).
  Future<List<CatalogStartup>> _resolveFavorites(List<String> ids) async {
    if (ids.isEmpty) {
      return const <CatalogStartup>[];
    }

    // Catálogo completo (cache local ou Cloud Function).
    final startups = await StartupCatalogListCache.instance.fullList(
      _functionsService,
    );

    // Mapa id → startup para lookup O(1).
    final byId = <String, CatalogStartup>{
      for (final s in startups)
        if (s.firestoreId != null && s.firestoreId!.isNotEmpty)
          s.firestoreId!: s,
    };

    // Mantém a ordem dos IDs gravados no Firestore.
    final out = <CatalogStartup>[];
    for (final id in ids) {
      final item = byId[id];
      if (item != null) {
        out.add(item);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final gradientStops = AppColors.shellGradientColors(theme.brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.shellOverlayStyle(theme.brightness),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientStops,
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const MesclaDetailHeader(),
                        const SizedBox(height: 16),
                        Text(
                          'Lista de Desejos',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Startups que guardou na lista de desejos.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // StreamBuilder reage quando favoritos mudam (add/remove no detalhe).
                        StreamBuilder<List<CatalogStartup>>(
                          stream: _favoritesStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Text(
                                  StartupCatalogFunctionsService.messageForError(
                                    snapshot.error!,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }

                            // Loading na primeira carga.
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 48),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final list =
                                snapshot.data ?? const <CatalogStartup>[];

                            // Pré-carrega logos fora do frame de build (performance).
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!context.mounted || list.isEmpty) return;
                              StartupLogoPrecacheService.schedulePreloadForStartupList(
                                context,
                                list,
                              );
                            });

                            // Estado vazio — orienta ir ao Explorar.
                            if (list.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 36),
                                child: Text(
                                  'Ainda não há startups na lista de desejos.\n'
                                  'Abra uma startup em Explorar e use Lista de Desejos.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              );
                            }

                            // Um CatalogStartupCard por favorito (mesmo widget do Explorar).
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final s in list) ...[
                                  CatalogStartupCard(
                                    startup: s,
                                    primary: colorScheme.primary,
                                    functionsService: _functionsService,
                                    onInvestir: widget.onInvestir,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
