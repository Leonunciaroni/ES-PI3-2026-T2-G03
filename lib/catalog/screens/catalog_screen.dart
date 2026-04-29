// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela Explorar (catálogo de startups) — protótipo visual alinhado ao Figma.
// A lista vem da callable `listStartups` via [StartupCatalogFunctionsService];
// em testes injeta-se [startupsFutureForTesting].

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalog_startup.dart';
import '../services/startup_catalog_functions_service.dart';
import '../services/startup_catalog_list_cache.dart';
import '../widgets/startup_logo_avatar.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import 'startup_detail_screen.dart';

/// Qual chip está ativo na barra horizontal (filtro por estágio).
///
/// O underscore no nome do enum deixa claro que é detalhe interno deste ficheiro.
enum _ChipFilter {
  todas,
  novas,
  emOperacao,
  emExpansao,
}

// --- Tela principal ---------------------------------------------------------

/// Tela **Explorar**: logo, busca, chips e lista de cards.
///
/// É um [StatefulWidget] porque:
/// - o texto da busca muda e precisamos de [setState] para refiltrar a lista;
/// - o chip selecionado também muda o estado visual e os itens visíveis.
///
/// Com [wrapWithSafeArea]: false, o antecessor aplica insets (ex.: shell do dashboard com bottom nav).
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    this.wrapWithSafeArea = true,
    this.startupsFutureForTesting,
    this.catalogFunctionsService,
    this.onInvestir,
  });

  /// Evita SafeArea duplicado quando a tela é filha de um [SafeArea] maior (dashboard shell).
  final bool wrapWithSafeArea;

  /// Quando não é null, a tela usa esta Future em vez da callable (útil em `flutter test`).
  /// Chips e busca filtram **localmente** sobre esta lista.
  final Future<List<CatalogStartup>>? startupsFutureForTesting;

  /// Injecção opcional da callable (testes / DI).
  final StartupCatalogFunctionsService? catalogFunctionsService;

  /// Chamado quando o utilizador toca "Investir Agora" dentro do detalhe.
  /// O [DashboardScreen] usa este callback para abrir o Balcão na startup certa.
  final void Function(CatalogStartup)? onInvestir;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  /// Controla o texto do campo "Buscar...". Precisa de [dispose] para libertar memória.
  final TextEditingController _searchController = TextEditingController();

  /// Chip atualmente escolhido (Todas, Novas, etc.).
  _ChipFilter _chipFilter = _ChipFilter.todas;

  static const _horizontalPadding = 20.0;

  late final StartupCatalogFunctionsService _functionsService;

  /// Pedido atual à callable (ou future de teste); novo objeto quando mudam chip/busca em produção.
  Future<List<CatalogStartup>>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _functionsService =
        widget.catalogFunctionsService ?? StartupCatalogFunctionsService();
    _loadFuture = _createLoadFuture();
  }

  /// Monta o [Future] conforme modo teste vs produção.
  Future<List<CatalogStartup>> _createLoadFuture() {
    if (widget.startupsFutureForTesting != null) {
      return widget.startupsFutureForTesting!;
    }
    final bool useSharedFullList = _chipFilter == _ChipFilter.todas &&
        _searchController.text.trim().isEmpty;
    if (useSharedFullList) {
      return StartupCatalogListCache.instance.fullList(_functionsService);
    }
    return _functionsService.listStartups(
      stage: _stageForChip(_chipFilter),
      search: _searchQueryForApi,
    );
  }

  /// Texto da busca ou null se vazio (enviado à Function).
  String? get _searchQueryForApi {
    final t = _searchController.text.trim();
    return t.isEmpty ? null : t;
  }

  /// Converte o chip da UI no estágio esperado pela API (`null` = todas).
  StartupStage? _stageForChip(_ChipFilter f) {
    switch (f) {
      case _ChipFilter.todas:
        return null;
      case _ChipFilter.novas:
        return StartupStage.nova;
      case _ChipFilter.emOperacao:
        return StartupStage.emOperacao;
      case _ChipFilter.emExpansao:
        return StartupStage.emExpansao;
    }
  }

  /// Em produção, novo pedido ao mudar chip ou texto; em teste só [setState] local.
  void _reloadFromBackendIfNeeded() {
    if (widget.startupsFutureForTesting != null) {
      return;
    }
    setState(() {
      _loadFuture = _createLoadFuture();
    });
  }

  @override
  void dispose() {
    // Sem isto, o TextEditingController mantém referências depois de sair da tela.
    _searchController.dispose();
    super.dispose();
  }

  /// A startup passa no filtro do chip? ("Todas" aceita sempre.)
  bool _matchesChip(CatalogStartup s) {
    switch (_chipFilter) {
      case _ChipFilter.todas:
        return true;
      case _ChipFilter.novas:
        return s.stage == StartupStage.nova;
      case _ChipFilter.emOperacao:
        return s.stage == StartupStage.emOperacao;
      case _ChipFilter.emExpansao:
        return s.stage == StartupStage.emExpansao;
    }
  }

  /// Pesquisa case-insensitive no nome, categoria, descrição e sigla (se existir).
  bool _matchesSearch(CatalogStartup s) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final String sigla = s.sigla?.toLowerCase() ?? '';
    return s.name.toLowerCase().contains(q) ||
        s.category.toLowerCase().contains(q) ||
        s.description.toLowerCase().contains(q) ||
        (sigla.isNotEmpty && sigla.contains(q));
  }

  /// Lista visível após aplicar chip + texto de busca sobre [all].
  List<CatalogStartup> _visibleFrom(List<CatalogStartup> all) {
    return all.where((s) => _matchesChip(s) && _matchesSearch(s)).toList();
  }

  /// Formata preço em estilo BR: "R$ 15,30" (sem separador de milhar nestes exemplos).
  String _formatTokenPrice(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    return 'R\$ ${parts[0]},${parts[1]}';
  }

  /// Quando o preço ainda não existe no backend usamos 0.0 e mostramos traço no card.
  String _tokenPriceLabel(CatalogStartup s) {
    if (s.tokenPrice <= 0) {
      return '—';
    }
    return _formatTokenPrice(s.tokenPrice);
  }

  /// Borda arredondada tipo "pílula" para o campo de busca.
  OutlineInputBorder _searchBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: color, width: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final gradientStops = AppColors.shellGradientColors(theme.brightness);
    final searchFill = AppColors.searchFieldFillForTheme(theme);

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
          child: _maybeSafeArea(
            wrap: widget.wrapWithSafeArea,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    // Scroll vertical: em ecrãs pequenos ou com teclado, tudo continua acessível.
                    padding: const EdgeInsets.fromLTRB(
                      _horizontalPadding,
                      8,
                      _horizontalPadding,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _CatalogHeader(),
                        const SizedBox(height: 20),
                        Text(
                          'Explorar',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Campo de busca: cor de fundo #E2E2E2 definida em [AppColors.searchFieldFill].
                        TextField(
                          controller: _searchController,
                          onChanged: (_) {
                            if (widget.startupsFutureForTesting != null) {
                              setState(() {});
                            } else {
                              _reloadFromBackendIfNeeded();
                            }
                          },
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Buscar startups, setores...',
                            suffixIcon: Icon(
                              Icons.search,
                              color: onSurface.withValues(alpha: 0.75),
                            ),
                            filled: true,
                            fillColor: searchFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            enabledBorder: _searchBorder(searchFill),
                            focusedBorder: _searchBorder(colorScheme.primary),
                            border: _searchBorder(searchFill),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Chips em [ListView] horizontal — não ocupam altura infinita.
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _FilterChip(
                                label: 'Todas',
                                selected: _chipFilter == _ChipFilter.todas,
                                onSelected: () => setState(() {
                                  _chipFilter = _ChipFilter.todas;
                                  if (widget.startupsFutureForTesting != null) {
                                    return;
                                  }
                                  _loadFuture = _createLoadFuture();
                                }),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Novas',
                                selected: _chipFilter == _ChipFilter.novas,
                                onSelected: () => setState(() {
                                  _chipFilter = _ChipFilter.novas;
                                  if (widget.startupsFutureForTesting != null) {
                                    return;
                                  }
                                  _loadFuture = _createLoadFuture();
                                }),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Em operação',
                                selected: _chipFilter == _ChipFilter.emOperacao,
                                onSelected: () => setState(() {
                                  _chipFilter = _ChipFilter.emOperacao;
                                  if (widget.startupsFutureForTesting != null) {
                                    return;
                                  }
                                  _loadFuture = _createLoadFuture();
                                }),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Em expansão',
                                selected: _chipFilter == _ChipFilter.emExpansao,
                                onSelected: () => setState(() {
                                  _chipFilter = _ChipFilter.emExpansao;
                                  if (widget.startupsFutureForTesting != null) {
                                    return;
                                  }
                                  _loadFuture = _createLoadFuture();
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        FutureBuilder<List<CatalogStartup>>(
                          future: _loadFuture,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Text(
                                  widget.startupsFutureForTesting != null
                                      ? 'Erro ao carregar dados de teste.'
                                      : StartupCatalogFunctionsService.messageForError(
                                          snapshot.error!,
                                        ),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.connectionState !=
                                    ConnectionState.done ||
                                !snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 48),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final List<CatalogStartup> raw = snapshot.data!;
                            final List<CatalogStartup> visible =
                                widget.startupsFutureForTesting != null
                                    ? _visibleFrom(raw)
                                    : raw;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...visible.map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _CatalogStartupCard(
                                      startup: s,
                                      tokenPriceFormatted: _tokenPriceLabel(s),
                                      primary: colorScheme.primary,
                                      onInvestir: widget.onInvestir,
                                    ),
                                  ),
                                ),
                                if (visible.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 32),
                                    child: Text(
                                      'Nenhuma startup encontrada.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
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

  /// SafeArea opcional para reutilizar a mesma árvore dentro ou fora de um shell com insets.
  static Widget _maybeSafeArea({required bool wrap, required Widget child}) {
    if (wrap) {
      return SafeArea(child: child);
    }
    return child;
  }
}

// --- Peças visuais privadas (só usadas neste ficheiro) -----------------------

/// Faixa superior com o logo Mescla Invest (tema claro/escuro).
class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader();

  static const _logoHeight = 52.0;
  static const _logoBoxWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MesclaBrandLogo(
          boxWidth: _logoBoxWidth,
          boxHeight: _logoHeight,
        ),
      ],
    );
  }
}

/// Chip retangular arredondado: roxo quando selecionado, cinza claro quando não.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final unselected = AppColors.themeMutedSurface(theme);
    return Material(
      color: selected ? primary : unselected,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Card com informações da startup (superfície alinhada ao Perfil no tema escuro).
class _CatalogStartupCard extends StatelessWidget {
  const _CatalogStartupCard({
    required this.startup,
    required this.tokenPriceFormatted,
    required this.primary,
    this.onInvestir,
  });

  final CatalogStartup startup;
  final String tokenPriceFormatted;
  final Color primary;
  final void Function(CatalogStartup)? onInvestir;

  /// Texto curto do badge conforme o estágio (para o utilizador ler rápido).
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

    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final result = await Navigator.of(context).push<CatalogStartup>(
            MaterialPageRoute<CatalogStartup>(
              builder: (context) => StartupDetailScreen(catalog: startup),
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
                          // Badge com contorno roxo (estágio).
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: primary.withValues(alpha: 0.5)),
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
                // Métricas à direita: rendimento (cor de destaque) e preço do token.
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
            // [ClipRRect] arredonda a barra; senão o progresso seria quadrado.
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
