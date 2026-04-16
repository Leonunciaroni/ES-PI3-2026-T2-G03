// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela Explorar (catálogo de startups) — protótipo visual alinhado ao Figma.
// Os dados vêm de listas fixas em memória; depois substituímos por chamadas à API.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

// --- Modelos de dados (simples, para o PI) ---------------------------------

/// Estágios possíveis de uma startup no ecossistema (documento MesclaInvest §5.2).
///
/// Usamos um [enum] para o compilador obrigar a tratar todos os casos no [switch].
enum StartupStage {
  nova,
  emOperacao,
  emExpansao,
}

/// Representa uma linha do catálogo: o que aparece no card na lista.
///
/// [captureProgress] vai de 0.0 a 1.0 e alimenta a [LinearProgressIndicator].
class CatalogStartup {
  const CatalogStartup({
    required this.name,
    required this.category,
    required this.stage,
    required this.yieldPercentLabel,
    required this.tokenPrice,
    required this.description,
    required this.captureProgress,
    required this.logoColor,
    required this.logoIcon,
  });

  final String name;
  final String category;
  final StartupStage stage;
  final String yieldPercentLabel;
  final double tokenPrice;
  final String description;

  /// Fração preenchida da barra (ex.: 0.8 = 80%).
  final double captureProgress;
  final Color logoColor;
  final IconData logoIcon;
}

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
/// Com [wrapWithSafeArea]: false, o antecessor aplica insets (ex.: [DashboardScreen] com bottom nav).
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, this.wrapWithSafeArea = true});

  /// Caminho do PNG registado em `pubspec.yaml` → `flutter: assets:`.
  static const String logoAsset = 'assets/images/mescla_logo.png';

  /// Evita SafeArea duplicado quando a tela é filha de um [SafeArea] maior (dashboard shell).
  final bool wrapWithSafeArea;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  /// Controla o texto do campo "Buscar...". Precisa de [dispose] para libertar memória.
  final TextEditingController _searchController = TextEditingController();

  /// Chip atualmente escolhido (Todas, Novas, etc.).
  _ChipFilter _chipFilter = _ChipFilter.todas;

  static const _horizontalPadding = 20.0;

  /// Dados de exemplo até existir backend (Firestore + API).
  static const List<CatalogStartup> _allStartups = [
    CatalogStartup(
      name: 'GreenFlow',
      category: 'AGROTECH',
      stage: StartupStage.nova,
      yieldPercentLabel: '+18.5%',
      tokenPrice: 15.30,
      description: 'Soluções de automações para a sua colheita',
      captureProgress: 0.8,
      logoColor: Color(0xFF22C55E),
      logoIcon: Icons.eco_outlined,
    ),
    CatalogStartup(
      name: 'CyberMesh',
      category: 'CYBERSECURITY',
      stage: StartupStage.emOperacao,
      yieldPercentLabel: '+12.3%',
      tokenPrice: 42.00,
      description: 'Monitoramento de ameaças em tempo real para PMEs',
      captureProgress: 0.55,
      logoColor: Color(0xFF18181B),
      logoIcon: Icons.security_outlined,
    ),
    CatalogStartup(
      name: 'Healthly',
      category: 'HEALTHTECH',
      stage: StartupStage.emExpansao,
      yieldPercentLabel: '+9.8%',
      tokenPrice: 8.75,
      description: 'Telemedicina e histórico clínico integrado',
      captureProgress: 0.92,
      logoColor: Color(0xFF14B8A6),
      logoIcon: Icons.favorite_outline,
    ),
  ];

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

  /// Pesquisa case-insensitive no nome, categoria e descrição.
  bool _matchesSearch(CatalogStartup s) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return s.name.toLowerCase().contains(q) ||
        s.category.toLowerCase().contains(q) ||
        s.description.toLowerCase().contains(q);
  }

  /// Lista que de facto aparece na tela (chip + caixa de busca em conjunto).
  List<CatalogStartup> get _visibleStartups {
    return _allStartups.where((s) => _matchesChip(s) && _matchesSearch(s)).toList();
  }

  /// Formata preço em estilo BR: "R$ 15,30" (sem separador de milhar nestes exemplos).
  String _formatTokenPrice(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    return 'R\$ ${parts[0]},${parts[1]}';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Ícones da barra de estado escuros — combinam com fundo claro em gradiente.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.gradientTop,
                AppColors.gradientBottom,
              ],
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
                          // Cada tecla dispara setState para atualizar a lista filtrada.
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Buscar startups, setores...',
                            suffixIcon: Icon(
                              Icons.search,
                              color: onSurface.withValues(alpha: 0.75),
                            ),
                            filled: true,
                            fillColor: AppColors.searchFieldFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            enabledBorder: _searchBorder(AppColors.searchFieldFill),
                            focusedBorder: _searchBorder(colorScheme.primary),
                            border: _searchBorder(AppColors.searchFieldFill),
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
                                onSelected: () =>
                                    setState(() => _chipFilter = _ChipFilter.todas),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Novas',
                                selected: _chipFilter == _ChipFilter.novas,
                                onSelected: () =>
                                    setState(() => _chipFilter = _ChipFilter.novas),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Em operação',
                                selected: _chipFilter == _ChipFilter.emOperacao,
                                onSelected: () => setState(
                                  () => _chipFilter = _ChipFilter.emOperacao,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Em expansão',
                                selected: _chipFilter == _ChipFilter.emExpansao,
                                onSelected: () => setState(
                                  () => _chipFilter = _ChipFilter.emExpansao,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Um card por startup visível; o operador ... expande o mapa para widgets filhos.
                        ..._visibleStartups.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CatalogStartupCard(
                              startup: s,
                              tokenPriceFormatted: _formatTokenPrice(s.tokenPrice),
                              primary: colorScheme.primary,
                            ),
                          ),
                        ),
                        if (_visibleStartups.isEmpty)
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

/// Faixa superior com o logo Mescla Invest (asset ou texto de fallback).
class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader();

  static const _logoHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          CatalogScreen.logoAsset,
          height: _logoHeight,
          fit: BoxFit.contain,
          // Se o PNG faltar no build, mostramos texto em vez de crash.
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'mescla invest',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            );
          },
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

  static const _unselectedBg = Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Material(
      color: selected ? primary : _unselectedBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Card branco com informações da startup (layout próximo ao Figma).
class _CatalogStartupCard extends StatelessWidget {
  const _CatalogStartupCard({
    required this.startup,
    required this.tokenPriceFormatted,
    required this.primary,
  });

  final CatalogStartup startup;
  final String tokenPriceFormatted;
  final Color primary;

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
      color: Colors.white,
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
                // "Avatar" quadrado com ícone representando o setor.
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: startup.logoColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(startup.logoIcon, color: Colors.white, size: 26),
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
                          color: AppColors.textSecondary,
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
                        color: AppColors.textSecondary,
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
                        color: AppColors.textSecondary,
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
                color: AppColors.textSecondary,
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
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
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
                backgroundColor: AppColors.gradientTop,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
