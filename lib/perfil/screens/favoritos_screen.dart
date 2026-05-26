// Lista de startups marcadas como favoritas — mesmo gradiente/cores do Explorar,
// cabeçalho [MesclaDetailHeader] como na tela de detalhes da startup, cards iguais ao catálogo.

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

  /// Igual ao Explorar: após «Investir Agora» no detalhe, abre o Balcão na startup certa.
  final void Function(CatalogStartup)? onInvestir;

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  late final StartupCatalogFunctionsService _functionsService;
  late final Stream<List<CatalogStartup>> _favoritesStream;

  @override
  void initState() {
    super.initState();
    _functionsService = StartupCatalogFunctionsService();
    _favoritesStream = UserFirestoreService.watchFavoriteStartupIds().asyncMap(
      _resolveFavorites,
    );
  }

  Future<List<CatalogStartup>> _resolveFavorites(List<String> ids) async {
    if (ids.isEmpty) {
      return const <CatalogStartup>[];
    }
    final startups =
        await StartupCatalogListCache.instance.fullList(_functionsService);
    final byId = <String, CatalogStartup>{
      for (final s in startups)
        if (s.firestoreId != null && s.firestoreId!.isNotEmpty) s.firestoreId!: s,
    };
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
                    // Mesmo recuo que [StartupDetailScreen._buildDetailScrollView].
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
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 48),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final list = snapshot.data ?? const <CatalogStartup>[];
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!context.mounted || list.isEmpty) return;
                              StartupLogoPrecacheService.schedulePreloadForStartupList(
                                context,
                                list,
                              );
                            });
                            if (list.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 36),
                                child: Text(
                                  'Ainda não há startups na lista de desejos.\n'
                                  'Abra uma startup em Explorar e use Lista de desejos.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              );
                            }
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
