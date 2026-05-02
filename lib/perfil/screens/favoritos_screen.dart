// Lista de startups marcadas como favoritas — mesmo gradiente/cores do Explorar,
// logo Mescla centrado e cards iguais ao catálogo.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/services/user_firestore_service.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../catalog/services/startup_catalog_functions_service.dart';
import '../../catalog/services/startup_logo_precache_service.dart';
import '../../catalog/widgets/catalog_startup_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';

/// Ecrã dedicado aos favoritos (aberto a partir do Perfil).
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  static const _horizontalPadding = 20.0;
  static const _logoHeight = 52.0;
  static const _logoBoxWidth = 200.0;

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
    final startups = await _functionsService.listStartups();
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back, color: onSurface),
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      FavoritosScreen._horizontalPadding,
                      8,
                      FavoritosScreen._horizontalPadding,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: MesclaBrandLogo(
                            boxWidth: FavoritosScreen._logoBoxWidth,
                            boxHeight: FavoritosScreen._logoHeight,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Favoritos',
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
                                  'Ainda não tem favoritos.\n'
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
