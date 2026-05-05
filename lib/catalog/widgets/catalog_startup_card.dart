// Card de startup do Explorar — reutilizado em Favoritos e no catálogo.

import 'package:flutter/material.dart';

import '../../navigation/mescla_material_route.dart';
import '../../navigation/mescla_navigation.dart';
import '../../theme/app_colors.dart';
import '../models/catalog_startup.dart';
import '../screens/startup_detail_screen.dart';
import '../services/startup_catalog_functions_service.dart';
import 'startup_logo_avatar.dart';

/// Formata preço do token como no catálogo (BR): `R$ 15,30` ou `—` se zero.
String catalogTokenPriceLabel(CatalogStartup s) {
  if (s.tokenPrice <= 0) {
    return '—';
  }
  final fixed = s.tokenPrice.toStringAsFixed(2);
  final parts = fixed.split('.');
  return 'R\$ ${parts[0]},${parts[1]}';
}

/// Card com informações da startup (mesmo estilo da lista Explorar).
class CatalogStartupCard extends StatelessWidget {
  const CatalogStartupCard({
    super.key,
    required this.startup,
    required this.primary,
    required this.functionsService,
    this.onInvestir,
  });

  final CatalogStartup startup;
  final Color primary;
  final StartupCatalogFunctionsService functionsService;
  final void Function(CatalogStartup)? onInvestir;

  String _stageBadgeLabel(StartupStage stage) {
    switch (stage) {
      case StartupStage.nova:
        return 'Nova';
      case StartupStage.emOperacao:
        return 'Em operação';
      case StartupStage.emExpansao:
        return 'Em expansão';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (startup.captureProgress * 100).round();
    final tokenPriceFormatted = catalogTokenPriceLabel(startup);

    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final prefetch =
              MesclaNavigationPrefetch.startupDetailPrefetchIfNeeded(
            service: functionsService,
            startup: startup,
          );
          final result = await Navigator.of(context).push<CatalogStartup>(
            MesclaMaterialRoute.fadeSlide<CatalogStartup>(
              (context) => StartupDetailScreen(
                catalog: startup,
                catalogFunctionsService: functionsService,
                prefetchDetailFuture: prefetch,
              ),
            ),
          );
          if (result != null) {
            onInvestir?.call(result);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StartupLogoAvatar(
                    logoPath: startup.logoPath,
                    fallbackColor: startup.logoColor,
                    fallbackIcon: startup.logoIcon,
                    size: 48,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                startup.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                _stageBadgeLabel(startup.stage),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          startup.category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'RENDIMENTO',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        startup.yieldPercentLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'VALOR DO TOKEN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tokenPriceFormatted,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                startup.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Progresso da captação',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: startup.captureProgress,
                  minHeight: 8,
                  backgroundColor: AppColors.progressTrack(theme),
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
