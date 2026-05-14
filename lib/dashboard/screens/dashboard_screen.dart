// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Dashboard (protótipo visual) — layout conforme Figma, sem backend.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/services/user_firestore_service.dart';
import '../../auth/services/session_persistence_service.dart';
import '../../balcao/screens/balcao_tab_screen.dart';
import '../../carteira/screens/carteira_screen.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../catalog/screens/catalog_screen.dart';
import '../../catalog/services/startup_catalog_functions_service.dart';
import '../../catalog/services/startup_catalog_list_cache.dart';
import '../../catalog/services/startup_logo_precache_service.dart';
import '../../navigation/mescla_navigation.dart';
import '../../navigation/mescla_tab_count.dart';
import '../../perfil/screens/perfil_screen.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mescla_header_row.dart';
import '../../widgets/mescla_main_shell.dart' show MesclaMainShell;

/// Tela inicial do app no modo dev: patrimônio, resumo e lista de startups.
///
/// O ícone de olho apenas oculta valores sensíveis localmente ([setState]).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.initialMainNavIndex = 0})
    : assert(
        initialMainNavIndex >= 0 && initialMainNavIndex < kMesclaMainTabCount,
      );

  /// Índice inicial da barra inferior (restaurado após login).
  final int initialMainNavIndex;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  /// Quando true, valores monetários e percentuais aparecem mascarados.
  bool _hideValues = false;

  /// Índice da barra inferior (Figma): 0 Início, 1 Carteira, 2 Balcão,
  /// 3 Catálogo, 4 Perfil.
  late int _mainNavIndex;

  /// Startup a abrir na mesa do Balcão (via "Investir Agora" no detalhe).
  CatalogStartup? _balcaoStartup;

  /// Incrementado a cada chamada de [_abrirBalcaoParaStartup], garantindo que
  /// a key do [BalcaoTabScreen] mude sempre — mesmo que a startup seja a mesma —
  /// e o [initState] seja re-executado com [initialMesaStartup] correto.
  int _balcaoNavCount = 0;

  static const _horizontalPadding = 20.0;
  static const _sectionGap = 24.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mainNavIndex = widget.initialMainNavIndex.clamp(
      0,
      kMesclaMainTabCount - 1,
    );
    unawaited(SessionPersistenceService.setLastNavIndex(_mainNavIndex));
    // Primeiro quadro garante [mounted] antes de usar [precacheImage] nos logos do catálogo.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _preloadCatalogLogoBitmaps(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_enforceSessionOnResume());
    }
  }

  Future<void> _enforceSessionOnResume() async {
    if (!mounted) {
      return;
    }
    final bool hasDeadline =
        await SessionPersistenceService.hasSessionDeadline();
    if (!mounted) {
      return;
    }
    if (!hasDeadline && FirebaseAuth.instance.currentUser != null) {
      await SessionPersistenceService.recordSessionAfterLogin();
      return;
    }
    final bool valid = await SessionPersistenceService.isRecordedSessionValid();
    if (!mounted || valid) {
      return;
    }
    try {
      await UserFirestoreService.signOut();
    } catch (_) {
      // Segue para o login mesmo se o sign-out falhar.
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Dispara logo o primeiro `listStartups` ([StartupCatalogListCache.fullList]); quando a lista
  /// regressa com sucesso agendamos descarga dos logos em segundo plano (sem bloquear a UI).
  void _preloadCatalogLogoBitmaps() {
    final service = StartupCatalogFunctionsService();
    StartupCatalogListCache.instance.fullList(service).then((
      List<CatalogStartup> list,
    ) {
      if (!mounted) return;
      StartupLogoPrecacheService.schedulePreloadForStartupList(context, list);
    });
  }

  /// Roxo → azul do card principal (Figma).
  static const _heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6234EA), Color(0xFF4F46E5)],
  );

  static const _walletIconColor = Color(0xFF92400E);

  /// Chamado pelo [CatalogScreen] quando o utilizador toca "Investir Agora".
  /// Troca para o Balcão e abre a mesa da [startup] diretamente.
  void _abrirBalcaoParaStartup(CatalogStartup startup) {
    setState(() {
      _balcaoStartup = startup;
      _balcaoNavCount++;
      _mainNavIndex = 2;
    });
  }

  void _toggleVisibility() {
    setState(() => _hideValues = !_hideValues);
  }

  /// Troca de separador na barra inferior: dispara pré-cargas úteis em paralelo
  /// com a perceção do utilizador (sem `await` — não bloqueia a animação).
  void _onMainNavIndexChanged(int i) {
    if (i == _mainNavIndex) {
      return;
    }
    unawaited(SessionPersistenceService.setLastNavIndex(i));
    if (i == 1) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        MesclaNavigationPrefetch.scheduleWalletFirestoreForCarteiraTab(
          user.uid,
        );
      }
    }
    if (i == 3) {
      final service = StartupCatalogFunctionsService();
      unawaited(StartupCatalogListCache.instance.fullList(service));
    }
    setState(() => _mainNavIndex = i);
  }

  String _money(double value) {
    if (_hideValues) return 'R\$ ••••••';
    // Formato BR: ponto como milhar e vírgula nos centavos (ex.: 12.450,00).
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    var intPart = parts[0];
    final dec = parts[1];
    final reversed = intPart.split('').reversed.join();
    final withDots = StringBuffer();
    for (var i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) withDots.write('.');
      withDots.write(reversed[i]);
    }
    intPart = withDots.toString().split('').reversed.join();
    return 'R\$ $intPart,$dec';
  }

  String _percent(String value) {
    if (_hideValues) return '•••';
    return value;
  }

  Widget _buildHomeTab(
    ThemeData theme,
    TextStyle? labelCaps,
    ColorScheme colorScheme,
    Color onSurface,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        8,
        _horizontalPadding,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MesclaHeaderRow(
            trailing: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_outlined),
              color: colorScheme.onSurface,
              tooltip: 'Notificações',
            ),
          ),
          const SizedBox(height: 20),
          Text('BOM DIA, RICARDO', style: labelCaps),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Seu Patrimônio',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: _toggleVisibility,
                icon: Icon(
                  _hideValues
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.secondaryLabel(theme),
                ),
                tooltip: _hideValues ? 'Mostrar valores' : 'Ocultar valores',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HeroCard(
            gradient: _heroGradient,
            totalLabel: 'SALDO TOTAL INVESTIDO',
            totalValue: _money(12450),
            trendText: '+ 14.2% este mês',
            hideChartValues: _hideValues,
          ),
          const SizedBox(height: _sectionGap),
          _SummaryCard(
            background: AppColors.themeMutedSurface(theme),
            icon: Icon(
              Icons.rocket_launch_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
            title: '4 Startups',
            subtitle: 'No portfólio ativo',
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            background: AppColors.themeMutedSurface(theme),
            icon: Icon(
              Icons.payments_outlined,
              color: _walletIconColor,
              size: 28,
            ),
            title: _money(1240),
            subtitle: 'Dividendos previstos',
          ),
          const SizedBox(height: _sectionGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Minhas Startups',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
              // Atalho da home: aba Catálogo (índice 3 após inclusão de Balcão).
              TextButton(
                onPressed: () => setState(() => _mainNavIndex = 3),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Ver todas',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StartupCard(
            name: 'GreenFlow',
            category: 'AGROTECH',
            yieldPercent: _percent('+18.5%'),
            invested: _money(4200),
            logoColor: const Color(0xFF22C55E),
            logoIcon: Icons.eco_outlined,
          ),
          const SizedBox(height: 12),
          _StartupCard(
            name: 'CyberMesh',
            category: 'CYBERSECURITY',
            yieldPercent: _percent('+12.3%'),
            invested: _money(3150),
            logoColor: const Color(0xFF18181B),
            logoIcon: Icons.security_outlined,
          ),
          const SizedBox(height: 12),
          _StartupCard(
            name: 'Healthly',
            category: 'HEALTHTECH',
            yieldPercent: _percent('+9.8%'),
            invested: _money(2800),
            logoColor: const Color(0xFF14B8A6),
            logoIcon: Icons.favorite_outline,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = theme.colorScheme.onSurface;

    final labelCaps = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.secondaryLabel(theme),
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    );

    return MesclaMainShell(
      selectedIndex: _mainNavIndex,
      onNavIndexChanged: _onMainNavIndexChanged,
      tabBodies: [
        _buildHomeTab(theme, labelCaps, colorScheme, onSurface),
        CarteiraScreen(
          // Força novo [State] após migração do período do gráfico para [ValuationPeriod]
          // (evita crash de tipo com hot reload / estado preso no [IndexedStack]).
          key: const ValueKey<String>('carteira_valuation_period'),
          wrapWithSafeArea: false,
          onCompraVendaTokens: () =>
              setState(() => _mainNavIndex = 2), // Balcão
        ),
        BalcaoTabScreen(
          key: ValueKey<int>(_balcaoNavCount),
          wrapWithSafeArea: false,
          initialMesaStartup: _balcaoStartup,
        ),
        CatalogScreen(
          wrapWithSafeArea: false,
          onInvestir: _abrirBalcaoParaStartup,
        ),
        PerfilScreen(
          wrapWithSafeArea: false,
          onInvestir: _abrirBalcaoParaStartup,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.gradient,
    required this.totalLabel,
    required this.totalValue,
    required this.trendText,
    required this.hideChartValues,
  });

  final Gradient gradient;
  final String totalLabel;
  final String totalValue;
  final String trendText;
  final bool hideChartValues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.seedPurple.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                totalLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                totalValue,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trendText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 56),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _HeroMiniBars(hideValues: hideChartValues),
          ),
        ],
      ),
    );
  }
}

/// Barras decorativas no canto do card roxo (Figma).
class _HeroMiniBars extends StatelessWidget {
  const _HeroMiniBars({required this.hideValues});

  final bool hideValues;

  static const _heights = <double>[12, 18, 14, 22, 28, 34, 40];

  @override
  Widget build(BuildContext context) {
    if (hideValues) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < _heights.length; i++) ...[
          Container(
            width: 7,
            height: _heights[i],
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35 + i * 0.04),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          if (i < _heights.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.background,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Color background;
  final Widget icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupCard extends StatelessWidget {
  const _StartupCard({
    required this.name,
    required this.category,
    required this.yieldPercent,
    required this.invested,
    required this.logoColor,
    required this.logoIcon,
  });

  final String name;
  final String category;
  final String yieldPercent;
  final String invested;
  final Color logoColor;
  final IconData logoIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: logoColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(logoIcon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      yieldPercent,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RENDIMENTO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Investido',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        invested,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                _SparklineBars(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini gráfico em barras roxas (sparkline) à direita do card.
class _SparklineBars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final heights = <double>[14, 22, 18, 28, 20, 32, 26];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < heights.length; i++) ...[
          Container(
            width: 5,
            height: heights[i],
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.35 + (i % 3) * 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (i < heights.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }
}
