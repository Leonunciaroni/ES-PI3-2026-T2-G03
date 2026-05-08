// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela Explorar (catálogo de startups) — protótipo visual alinhado ao Figma.
// A lista vem da callable `listStartups` via [StartupCatalogFunctionsService];
// em testes injeta-se [startupsFutureForTesting].

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalog_startup.dart';
import '../services/startup_catalog_functions_service.dart';
import '../services/startup_catalog_list_cache.dart';
import '../services/startup_firestore_mapper.dart';
import '../services/startup_logo_precache_service.dart';
import '../widgets/catalog_startup_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';

/// Qual chip está ativo na barra horizontal (filtro por estágio).
///
/// O underscore no nome do enum deixa claro que é detalhe interno deste ficheiro.
enum _ChipFilter {
  todas,
  novas,
  emOperacao,
  emExpansao,
}

/// Firebase inicializado (Firestore ao vivo para `preco_token`).
bool _catalogFirebaseAoVivo() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
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
    _kickLogoPrefetchWhenListReady();
  }

  /// Após cada regressão ao backend (callable ou cache global), aquece fotos Storage em fundo
  /// assim que há [mounted] ([StartupLogoPrecacheService]) para reduzir spinners mesmo indo já para Explorar.
  void _kickLogoPrefetchWhenListReady() {
    final fut = _loadFuture;
    if (fut == null) return;
    fut.then((list) {
      if (!mounted) return;
      StartupLogoPrecacheService.schedulePreloadForStartupList(context, list);
    });
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

  /// Troca estágio pelo chip bar e refaz lista em produção; em testes filtra apenas localmente.
  void _updateChipSelection(_ChipFilter chip) {
    setState(() {
      _chipFilter = chip;
      if (widget.startupsFutureForTesting != null) {
        return;
      }
      _loadFuture = _createLoadFuture();
    });
    if (widget.startupsFutureForTesting == null) {
      _kickLogoPrefetchWhenListReady();
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
    _kickLogoPrefetchWhenListReady();
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

  /// Cards do Explorar; em produção com Firebase, o `preco_token` vem do snapshot
  /// da coleção [kFirestoreStartupsCollection] (atualização contínua pelo scheduler).
  Widget _catalogListaComPrecoAoVivo({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required List<CatalogStartup> raw,
  }) {
    final List<CatalogStartup> visible =
        widget.startupsFutureForTesting != null
            ? _visibleFrom(raw)
            : raw;

    Widget coluna(List<CatalogStartup> rows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CatalogStartupCard(
                startup: s,
                primary: colorScheme.primary,
                functionsService: _functionsService,
                onInvestir: widget.onInvestir,
              ),
            ),
          ),
          if (rows.isEmpty)
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
    }

    if (widget.startupsFutureForTesting != null || !_catalogFirebaseAoVivo()) {
      return coluna(visible);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(kFirestoreStartupsCollection)
          .snapshots(),
      builder: (context, fsSnap) {
        List<CatalogStartup> merged = raw;
        if (fsSnap.hasData) {
          final m = <String, double>{};
          for (final d in fsSnap.data!.docs) {
            m[d.id] = tokenPriceFromFirestore(d.data());
          }
          merged = catalogMergeLivePrecoToken(raw, m);
        }
        final rows = merged;
        return coluna(rows);
      },
    );
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
                                onSelected: () => _updateChipSelection(_ChipFilter.todas),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Novas',
                                selected: _chipFilter == _ChipFilter.novas,
                                onSelected: () => _updateChipSelection(_ChipFilter.novas),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Em operação',
                                selected: _chipFilter == _ChipFilter.emOperacao,
                                onSelected: () =>
                                    _updateChipSelection(_ChipFilter.emOperacao),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Em expansão',
                                selected: _chipFilter == _ChipFilter.emExpansao,
                                onSelected: () =>
                                    _updateChipSelection(_ChipFilter.emExpansao),
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
                            return _catalogListaComPrecoAoVivo(
                              theme: theme,
                              colorScheme: colorScheme,
                              raw: raw,
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

