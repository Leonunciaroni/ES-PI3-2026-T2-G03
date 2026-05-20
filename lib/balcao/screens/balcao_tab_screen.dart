// Autor: Leonardo Miranda Nunciaroni
// RA: 25002726
//
// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Aba **Balcão** (índice 2 do [MesclaMainShell]): lista de startups pela callable
// `listStartups` (como o Explorar), depois mesa com saldo e histórico reais quando
// há sessão + `firestoreId`, compra/venda à mercado e fluxo quantidade → modal → senha → detalhe (§5.3 MesclaInvest).

import 'dart:async' show Timer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../catalog/data/startup_detail_mock.dart';
import '../balcao_cotacao_chart_series.dart';
import '../balcao_format.dart';
import '../../navigation/mescla_material_route.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../catalog/services/startup_catalog_functions_service.dart';
import '../../catalog/services/startup_catalog_list_cache.dart';
import '../../catalog/services/startup_logo_precache_service.dart';
import '../../catalog/widgets/startup_logo_avatar.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../../widgets/mescla_header_row.dart';
import '../../widgets/valuation_evolution_chart_card.dart';
import '../models/balcao_operacao_tipo.dart';
import '../models/balcao_transacao.dart';
import '../widgets/order_book_panel.dart';
import 'balcao_quantidade_tokens_screen.dart';

/// Abreviatura exibida como identificação do token (ex.: sigla ou prefixo do nome).
///
/// Não confundir com ticker de bolsa real — aqui é só rótulo de UI para o PI.
String balcaoTickerParaStartup(CatalogStartup s) {
  final raw = s.sigla?.trim();
  if (raw != null && raw.isNotEmpty) {
    return raw.toUpperCase();
  }
  final n = s.name.trim();
  if (n.length <= 5) return n.toUpperCase();
  return '${n.substring(0, 4).toUpperCase()}…';
}

DateTime _balcaoDiaCivilLocal(DateTime d) =>
    DateTime(d.year, d.month, d.day);

bool _balcaoTransacaoNoIntervaloDias({
  required DateTime whenLocal,
  required DateTime inicioDiaInclusive,
  required DateTime fimDiaInclusive,
}) {
  final dia = _balcaoDiaCivilLocal(whenLocal);
  final a = _balcaoDiaCivilLocal(inicioDiaInclusive);
  final b = _balcaoDiaCivilLocal(fimDiaInclusive);
  return !dia.isBefore(a) && !dia.isAfter(b);
}

String _balcaoFmtDataCurta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Compras/vendas à mercado no ledger, filtradas pela startup e por **dias civis**
/// locais `[inicioDiaLocalInclusive, fimDiaLocalInclusive]`.
List<BalcaoTransacaoDia> _filtrarTradesLedgerPorStartupEIntervalo({
  required QuerySnapshot<Map<String, dynamic>> ledgerSnap,
  required String startupFirestoreId,
  required DateTime inicioDiaLocalInclusive,
  required DateTime fimDiaLocalInclusive,
}) {
  final out = <BalcaoTransacaoDia>[];

  for (final doc in ledgerSnap.docs) {
    final d = doc.data();
    final ts = d['createdAt'];

    DateTime? whenLocal;
    if (ts is Timestamp) {
      whenLocal = ts.toDate();
    }
    if (whenLocal == null ||
        !_balcaoTransacaoNoIntervaloDias(
          whenLocal: whenLocal,
          inicioDiaInclusive: inicioDiaLocalInclusive,
          fimDiaInclusive: fimDiaLocalInclusive,
        )) {
      continue;
    }

    final op = d['op'] as String?;
    if (op != 'trade_buy' && op != 'trade_sell') continue;

    final sid = d['startupId'];
    final sidStr = sid is String ? sid : '';
    if (sidStr.isEmpty || sidStr != startupFirestoreId) continue;

    final amount = d['amountBrl'];
    final vb = amount is num ? amount.toDouble() : 0.0;
    if (!(vb > 0)) continue;

    final tipo = op == 'trade_buy'
        ? BalcaoOperacaoTipo.compra
        : BalcaoOperacaoTipo.venda;

    final headline =
        clipLedgerHeadline(d['headline']) ?? 'Mercado · Balcão simulado';

    out.add(
      BalcaoTransacaoDia(
        tipo: tipo,
        resumo: headline,
        valorReais: vb,
        dataHora: whenLocal,
      ),
    );
  }

  out.sort((a, b) {
    final ta =
        a.dataHora ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final tb =
        b.dataHora ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return tb.compareTo(ta);
  });

  return out;
}

/// Headline auditorável truncada só para lista do dia na UI (evita texto vazio estranho).
String? clipLedgerHeadline(dynamic raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  final s = raw.trim();
  const maxLen = 80;
  return s.length > maxLen ? '${s.substring(0, maxLen)}…' : s;
}

bool _mesaFirebaseAppsProntos() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

String _balcaoLinhaSubtitleExtrato(BalcaoTransacaoDia item) {
  final quando = item.dataHora;
  if (quando == null) {
    return item.resumo;
  }
  final data = _balcaoFmtDataCurta(quando);
  final h = quando.hour.toString().padLeft(2, '0');
  final m = quando.minute.toString().padLeft(2, '0');
  return '${item.resumo} · $data · $h:$m';
}

/// Variação % na série 24h — [null] se não for calculável (ex.: cotação base ~0, evita NaN%).
double? balcaoVariacao24hPercentual(List<double> serie) {
  if (serie.length < 2) return null;
  final a = serie.first;
  final b = serie.last;
  if (!a.isFinite || !b.isFinite) return null;
  if (a.abs() < 1e-12) return null;
  final pct = 100.0 * (b - a) / a;
  if (!pct.isFinite) return null;
  return pct;
}

/// Ex.: `+12,3%` / `-4,5%` / `0,0%` — uma casa decimal, alinhado ao resto da app.
String balcaoFmtVariacaoPercentualPt(double pct) {
  final x = (pct * 10).round() / 10.0;
  final absStr = x.abs().toStringAsFixed(1).replaceAll('.', ',');
  if (x > 0.05) {
    return '+$absStr';
  }
  if (x < -0.05) {
    return '-$absStr';
  }
  return '0,0';
}

/// Cotação ou saldo em reais: traço se o preço do token ainda não existe no back-end.
String balcaoBrlDisponivel(double valorReais, bool precoConhecido) {
  if (!precoConhecido || !valorReais.isFinite) return '—';
  return formatBrl(valorReais);
}

/// Tela principal do separador Balcão: primeiro escolhe startup, depois negocia.
///
/// [wrapWithSafeArea]: `false` quando o pai já é o [MesclaMainShell] com insets.
/// [startupsFutureForTesting] e [catalogFunctionsService] seguem o mesmo padrão do [CatalogScreen].
class BalcaoTabScreen extends StatefulWidget {
  const BalcaoTabScreen({
    super.key,
    this.wrapWithSafeArea = true,
    this.initialMesaStartup,
    this.startupsFutureForTesting,
    this.catalogFunctionsService,
  });

  final bool wrapWithSafeArea;
  final CatalogStartup? initialMesaStartup;
  final Future<List<CatalogStartup>>? startupsFutureForTesting;
  final StartupCatalogFunctionsService? catalogFunctionsService;

  @override
  State<BalcaoTabScreen> createState() => _BalcaoTabScreenState();
}

class _BalcaoTabScreenState extends State<BalcaoTabScreen>
    with SingleTickerProviderStateMixin {
  late final StartupCatalogFunctionsService _functionsService;

  /// Abas da mesa: Compra Rápida | Order Book.
  late final TabController _mesaTabController;

  /// Lista inicial (callable ou future de teste).
  late final Future<List<CatalogStartup>> _listFuture;

  /// Opcional: detalhe enriquecido para o gráfico da mesa quando há `firestoreId`.
  Future<StartupDetailViewData?>? _mesaDetailFuture;

  /// Igual ao [CatalogScreen] — filtra a lista, sem barra de chips de estágio.
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  static const Duration _kSearchDebounceDelay = Duration(milliseconds: 200);

  /// Se null, mostramos a **lista**; se preenchido, mostramos a **mesa** dessa startup.
  CatalogStartup? _mesaStartup;

  /// Cotação oficial (última leitura de [fetchStartupMarketStats]) para efeitos de UI.
  double? _mesaCotacaoOficialBrl;

  /// ID da startup cuja mesa tem refresh periódico da cotação (alinhado ao Scheduler).
  String? _mesaMarketRefreshStartupId;

  /// Dispara [setState] a cada [_mesaMarketRefreshMinutes] enquanto a mesa estiver aberta.
  Timer? _mesaMarketRefreshTimer;

  /// Mesmo intervalo por defeito que o backend (`MARKET_TICK_SCHEDULE` ≈ 20 min).
  static const int _mesaMarketRefreshMinutes = 20;

  /// Filtro do gráfico de cotação (mesmos períodos do detalhe da startup).
  ValuationPeriod _periodoCotacao = ValuationPeriod.mensal;

  /// Primeiro e último dia civil (local) para listar compras/vendas na mesa (inclusive).
  late DateTime _mesaExtratoFiltroInicioDia;
  late DateTime _mesaExtratoFiltroFimDia;

  static const _horizontalPadding = 20.0;

  /// Scroll do corpo: ao alternar lista ↔ mesa, voltamos ao topo (evita offset estranho).
  final ScrollController _bodyScrollController = ScrollController();

  /// Chave estável para [AnimatedSwitcher] distinguir lista vs. mesa (e cada startup).
  String get _balcaoPainelKey => _mesaStartup == null
      ? 'balcao_lista'
      : 'mesa_${_mesaStartup!.firestoreId ?? _mesaStartup!.name}';

  @override
  void initState() {
    super.initState();
    _mesaTabController = TabController(length: 2, vsync: this);
    _functionsService =
        widget.catalogFunctionsService ?? StartupCatalogFunctionsService();
    _listFuture =
        widget.startupsFutureForTesting ??
        StartupCatalogListCache.instance.fullList(_functionsService);
    _listFuture.then((list) {
      if (!mounted) return;
      StartupLogoPrecacheService.schedulePreloadForStartupList(context, list);
    });
    _mesaStartup = widget.initialMesaStartup;
    final CatalogStartup? mesa = _mesaStartup;
    if (mesa?.firestoreId != null) {
      _mesaDetailFuture = _functionsService.fetchStartupDetail(
        mesa!.firestoreId!,
      );
    }
    final n = DateTime.now();
    final hoje = DateTime(n.year, n.month, n.day);
    _mesaExtratoFiltroInicioDia = hoje;
    _mesaExtratoFiltroFimDia = hoje;
    _syncMesaMarketRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant BalcaoTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMesaMarketRefreshTimer();
  }

  /// Mantém um timer que força novo [fetchStartupMarketStats] enquanto o utilizador
  /// está na mesa (preço simulado no servidor evolui a cada ~20 min).
  void _syncMesaMarketRefreshTimer() {
    final mesa = _mesaStartup;
    final fid = mesa?.firestoreId?.trim();
    final activo = mesa != null &&
        fid != null &&
        fid.isNotEmpty &&
        _mesaFirebaseAppsProntos();
    if (!activo) {
      _mesaMarketRefreshTimer?.cancel();
      _mesaMarketRefreshTimer = null;
      _mesaMarketRefreshStartupId = null;
      return;
    }
    if (_mesaMarketRefreshStartupId == fid && _mesaMarketRefreshTimer != null) {
      return;
    }
    _mesaMarketRefreshTimer?.cancel();
    _mesaMarketRefreshStartupId = fid;
    _mesaMarketRefreshTimer =
        Timer.periodic(const Duration(minutes: _mesaMarketRefreshMinutes), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _mesaTabController.dispose();
    _mesaMarketRefreshTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounceDelay, () {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _jumpBodyScrollTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_bodyScrollController.hasClients) {
        _bodyScrollController.jumpTo(0);
      }
    });
  }

  /// Lista → mesa: mesma linguagem visual das rotas Mescla (fade + micro-slide).
  void _abrirMesa(CatalogStartup s) {
    setState(() {
      _mesaStartup = s;
      _mesaCotacaoOficialBrl = null;
      _periodoCotacao = ValuationPeriod.mensal;
      _mesaDetailFuture = s.firestoreId != null
          ? _functionsService.fetchStartupDetail(s.firestoreId!)
          : null;
      final n = DateTime.now();
      final hoje = DateTime(n.year, n.month, n.day);
      _mesaExtratoFiltroInicioDia = hoje;
      _mesaExtratoFiltroFimDia = hoje;
    });
    _syncMesaMarketRefreshTimer();
    _jumpBodyScrollTop();
  }

  /// Intervalo de datas do extrato da mesa (compras/vendas à mercado).
  Future<void> _mesaEscolherPeriodoExtrato() async {
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: hoje,
      initialDateRange: DateTimeRange(
        start: _mesaExtratoFiltroInicioDia,
        end: _mesaExtratoFiltroFimDia,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _mesaExtratoFiltroInicioDia =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      _mesaExtratoFiltroFimDia =
          DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
  }

  void _mesaExtratoResetHoje() {
    final n = DateTime.now();
    final hoje = DateTime(n.year, n.month, n.day);
    setState(() {
      _mesaExtratoFiltroInicioDia = hoje;
      _mesaExtratoFiltroFimDia = hoje;
    });
  }

  /// Mesma regra do catálogo: nome, categoria, descrição, sigla.
  bool _matchesSearch(CatalogStartup s) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final String sigla = s.sigla?.toLowerCase() ?? '';
    return s.name.toLowerCase().contains(q) ||
        s.category.toLowerCase().contains(q) ||
        s.description.toLowerCase().contains(q) ||
        (sigla.isNotEmpty && sigla.contains(q));
  }

  /// Volta ao modo lista (mantém a bottom bar do shell visível).
  void _limparMesa() {
    setState(() {
      _mesaStartup = null;
      _mesaCotacaoOficialBrl = null;
      _periodoCotacao = ValuationPeriod.mensal;
      _mesaDetailFuture = null;
    });
    _syncMesaMarketRefreshTimer();
    _jumpBodyScrollTop();
  }

  /// Abre o ecrã onde o utilizador define a **quantidade**; o modal e a senha
  /// vêm a seguir nessa mesma cadeia de rotas.
  Future<void> _iniciarFluxoOperacao(BalcaoOperacaoTipo operacao) async {
    final startup = _mesaStartup;
    if (startup == null) return;

    await Navigator.of(context).push<void>(
      MesclaMaterialRoute.fadeSlide<void>(
        (context) => BalcaoQuantidadeTokensScreen(
          startup: startup,
          operacao: operacao,
          cotacaoOficialBrl: _mesaCotacaoOficialBrl,
        ),
      ),
    );
  }

  /// Evita usar `FirebaseAuth` em testes de widget sem [Firebase.initializeApp].
  Widget _balcaoMesaSemFirebaseAoVivo({
    required ThemeData theme,
    required ColorScheme scheme,
    required Color onSurface,
  }) {
    final mesaStartup = _mesaStartup!;
    final fut = _mesaDetailFuture;
    const aviso =
        'Carteira ao vivo indisponível (Firebase não inicializado neste contexto).';

    Widget coluna(StartupDetailViewData detail) {
      final precoMercado = mesaStartup.tokenPrice > 1e-9
          ? mesaStartup.tokenPrice
          : 0.0;
      return _balcaoMesaComAbas(
        theme: theme,
        scheme: scheme,
        mesaStartup: mesaStartup,
        precoMercadoBrl: precoMercado,
        tabCompraRapida: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _balcaoMesaTradingColumn(
              theme: theme,
              scheme: scheme,
              s: mesaStartup,
              detail: detail,
              onPeriodo: (ValuationPeriod p) =>
                  setState(() => _periodoCotacao = p),
              comprar: () =>
                  _iniciarFluxoOperacao(BalcaoOperacaoTipo.compra),
              vender: () =>
                  _iniciarFluxoOperacao(BalcaoOperacaoTipo.venda),
              saldoTokensHeld: 0,
              disponivelCarteiraBrlTexto: '—',
              totalPosicaoBrlTexto: '—',
              precoMercadoBrl: precoMercado,
              marketStats: null,
            ),
            const SizedBox(height: 28),
            Text(
              'Transações de hoje · mercado',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              aviso,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryLabel(theme),
              ),
            ),
          ],
        ),
      );
    }

    if (fut == null) {
      return coluna(startupDetailFor(mesaStartup));
    }
    return FutureBuilder<StartupDetailViewData?>(
      future: fut,
      builder: (context, snapshot) {
        final StartupDetailViewData detail =
            snapshot.hasData && snapshot.data != null
                ? snapshot.data!
                : startupDetailFor(mesaStartup);
        return coluna(detail);
      },
    );
  }

  Widget _wrapBody(Widget child) {
    if (!widget.wrapWithSafeArea) return child;
    return SafeArea(child: child);
  }

  /// Borda do campo de busca (igual ao [CatalogScreen]).
  OutlineInputBorder _searchBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: color, width: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final searchFill = AppColors.searchFieldFillForTheme(theme);

    final scroll = SingleChildScrollView(
      controller: _bodyScrollController,
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        8,
        _horizontalPadding,
        24,
      ),
      child: AnimatedSwitcher(
        duration: MesclaMaterialRoute.kTransitionDuration,
        reverseDuration: MesclaMaterialRoute.kReverseTransitionDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<String>(_balcaoPainelKey),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_mesaStartup == null) ...[
                const _BalcaoLogoHeader(),
                const SizedBox(height: 20),
                Text(
                  'Balcão',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Escolha uma startup para ver saldo em tokens e negociar.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _onSearchChanged(),
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
                    focusedBorder: _searchBorder(scheme.primary),
                    border: _searchBorder(searchFill),
                  ),
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<CatalogStartup>>(
                  future: _listFuture,
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
                            color: AppColors.secondaryLabel(theme),
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState != ConnectionState.done ||
                        !snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final all = snapshot.data!;
                    if (all.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Text(
                          'Nenhuma startup disponível.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                          ),
                        ),
                      );
                    }
                    final list = all.where(_matchesSearch).toList();
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Text(
                          'Nenhuma startup encontrada.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final s in list) ...[
                          _BalcaoStartupRowCard(
                            startup: s,
                            ticker: balcaoTickerParaStartup(s),
                            primary: scheme.primary,
                            onTap: () => _abrirMesa(s),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ] else ...[
                _BalcaoMesaTopRow(onBack: _limparMesa),
                const SizedBox(height: 20),
                if (!_mesaFirebaseAppsProntos())
                  _balcaoMesaSemFirebaseAoVivo(
                    theme: theme,
                    scheme: scheme,
                    onSurface: onSurface,
                  )
                else
                  StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, authSnap) {
                    final mesaStartup = _mesaStartup!;
                    final fid = mesaStartup.firestoreId?.trim();
                    final user = authSnap.data;
                    final carteiraAoVivo =
                        user != null &&
                        fid != null &&
                        fid.isNotEmpty;

                    Widget montarPainelCarteiraStreams({
                      required StartupDetailViewData detail,
                      required double saldoTokensEmCarteira,
                      required String disponivelBrlFmt,
                      required String avisoConvidado,
                      required double precoMercadoBrl,
                      BalcaoStartupMarketStats? marketStats,
                    }) {
                      final precoConhecido = precoMercadoBrl > 1e-9;
                      final totalPosicaoFmt = !carteiraAoVivo
                          ? '—'
                          : !precoConhecido
                              ? '—'
                              : balcaoBrlDisponivel(
                                  saldoTokensEmCarteira * precoMercadoBrl,
                                  true,
                                );

                      if (!carteiraAoVivo) {
                        return _balcaoMesaComAbas(
                          theme: theme,
                          scheme: scheme,
                          mesaStartup: mesaStartup,
                          precoMercadoBrl: precoMercadoBrl,
                          tabCompraRapida: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _balcaoMesaTradingColumn(
                                theme: theme,
                                scheme: scheme,
                                s: mesaStartup,
                                detail: detail,
                                onPeriodo: (ValuationPeriod p) =>
                                    setState(() => _periodoCotacao = p),
                                comprar: () => _iniciarFluxoOperacao(
                                  BalcaoOperacaoTipo.compra,
                                ),
                                vender: () => _iniciarFluxoOperacao(
                                  BalcaoOperacaoTipo.venda,
                                ),
                                saldoTokensHeld: saldoTokensEmCarteira,
                                disponivelCarteiraBrlTexto: disponivelBrlFmt,
                                totalPosicaoBrlTexto: totalPosicaoFmt,
                                precoMercadoBrl: precoMercadoBrl,
                                marketStats: marketStats,
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'Transações · mercado',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                avisoConvidado,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.secondaryLabel(theme),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>
                      >(
                        stream: SimulatedWalletService.watchLedgerRecentForChart(
                          user.uid,
                          limit: 500,
                        ),
                        builder: (context, ledgerShot) {
                          final txs = ledgerShot.hasData
                              ? _filtrarTradesLedgerPorStartupEIntervalo(
                                  ledgerSnap: ledgerShot.data!,
                                  startupFirestoreId: fid,
                                  inicioDiaLocalInclusive:
                                      _mesaExtratoFiltroInicioDia,
                                  fimDiaLocalInclusive: _mesaExtratoFiltroFimDia,
                                )
                              : const <BalcaoTransacaoDia>[];

                          return _balcaoMesaComAbas(
                            theme: theme,
                            scheme: scheme,
                            mesaStartup: mesaStartup,
                            precoMercadoBrl: precoMercadoBrl,
                            tabCompraRapida: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _balcaoMesaTradingColumn(
                                  theme: theme,
                                  scheme: scheme,
                                  s: mesaStartup,
                                  detail: detail,
                                  onPeriodo: (ValuationPeriod p) =>
                                      setState(() => _periodoCotacao = p),
                                  comprar: () => _iniciarFluxoOperacao(
                                    BalcaoOperacaoTipo.compra,
                                  ),
                                  vender: () => _iniciarFluxoOperacao(
                                    BalcaoOperacaoTipo.venda,
                                  ),
                                  saldoTokensHeld: saldoTokensEmCarteira,
                                  disponivelCarteiraBrlTexto: disponivelBrlFmt,
                                  totalPosicaoBrlTexto: totalPosicaoFmt,
                                  precoMercadoBrl: precoMercadoBrl,
                                  marketStats: marketStats,
                                ),
                                const SizedBox(height: 28),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Transações · mercado',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_balcaoFmtDataCurta(_mesaExtratoFiltroInicioDia)} – ${_balcaoFmtDataCurta(_mesaExtratoFiltroFimDia)}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: AppColors.secondaryLabel(
                                                theme,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _mesaEscolherPeriodoExtrato,
                                      child: const Text('Período'),
                                    ),
                                    TextButton(
                                      onPressed: _mesaExtratoResetHoje,
                                      child: const Text('Hoje'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (ledgerShot.connectionState ==
                                        ConnectionState.waiting &&
                                    !ledgerShot.hasData)
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (txs.isEmpty)
                                  Text(
                                    'Nenhuma compra ou venda neste par no período.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.secondaryLabel(theme),
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final tx in txs) ...[
                                        _TransacaoDiaTile(
                                          item: tx,
                                          primary: scheme.primary,
                                          theme: theme,
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    }

                    Widget tradingComCarteiraAoVivo(
                      StartupDetailViewData detail, {
                      required double precoMercadoBrl,
                      BalcaoStartupMarketStats? marketStats,
                    }) {
                      final u = user!;
                      return StreamBuilder<double>(
                        stream: SimulatedWalletService.watchTokensHeld(
                          u.uid,
                          fid!,
                        ),
                        builder: (context, posShot) {
                          return StreamBuilder<double>(
                            stream: SimulatedWalletService.watchBrlBalance(
                              u.uid,
                            ),
                            builder: (context, brlShot) {
                              final saldoT = posShot.data ?? 0;
                              final brlSaldoCarteira =
                                  brlShot.data ?? 0;
                              return montarPainelCarteiraStreams(
                                detail: detail,
                                saldoTokensEmCarteira: saldoT,
                                disponivelBrlFmt: formatBrl(
                                  brlSaldoCarteira,
                                ),
                                avisoConvidado: '',
                                precoMercadoBrl: precoMercadoBrl,
                                marketStats: marketStats,
                              );
                            },
                          );
                        },
                      );
                    }

                    final fut = _mesaDetailFuture;
                    final precoConvidado =
                        mesaStartup.tokenPrice > 1e-9
                            ? mesaStartup.tokenPrice
                            : 0.0;
                    if (!carteiraAoVivo) {
                      final detail = startupDetailFor(mesaStartup);
                      return montarPainelCarteiraStreams(
                        detail: detail,
                        saldoTokensEmCarteira: 0,
                        disponivelBrlFmt: '—',
                        avisoConvidado:
                            'Para ver tokens e extrato ligados ao Balcão, entre com conta e-mail neste equipamento.',
                        precoMercadoBrl: precoConvidado,
                        marketStats: null,
                      );
                    }
                    return FutureBuilder<BalcaoStartupMarketStats?>(
                      key: ValueKey<String>('mesa_market_$fid'),
                      future: SimulatedWalletService.fetchStartupMarketStats(
                        fid,
                      ),
                      builder: (context, statsSnap) {
                        final st = statsSnap.data;
                        final oficial = st?.tokenPriceBrl;

                        /// Sem snapshot ainda: não usar preço do catálogo (evita flash do valor
                        /// “antigo” antes da cotação simulada no Firestore).
                        final semSnapshot =
                            statsSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !statsSnap.hasData;

                        final double precoMercado;
                        if (oficial != null && oficial > 1e-9) {
                          precoMercado = oficial;
                        } else if (semSnapshot) {
                          final prev = _mesaCotacaoOficialBrl;
                          precoMercado =
                              (prev != null && prev > 1e-9) ? prev : 0.0;
                        } else {
                          precoMercado =
                              mesaStartup.tokenPrice > 1e-9
                                  ? mesaStartup.tokenPrice
                                  : 0.0;
                        }
                        if (statsSnap.connectionState ==
                            ConnectionState.done) {
                          final next = (oficial != null && oficial > 1e-9)
                              ? oficial
                              : null;
                          if (next != _mesaCotacaoOficialBrl) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() => _mesaCotacaoOficialBrl = next);
                            });
                          }
                        }

                        if (fut == null) {
                          final detail = startupDetailFor(mesaStartup);
                          return tradingComCarteiraAoVivo(
                            detail,
                            precoMercadoBrl: precoMercado,
                            marketStats: st,
                          );
                        }
                        return FutureBuilder<StartupDetailViewData?>(
                          future: fut,
                          builder: (context, snapshot) {
                            final StartupDetailViewData detail =
                                snapshot.hasData && snapshot.data != null
                                    ? snapshot.data!
                                    : startupDetailFor(mesaStartup);
                            return tradingComCarteiraAoVivo(
                              detail,
                              precoMercadoBrl: precoMercado,
                              marketStats: st,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.shellOverlayStyle(theme.brightness),
      child: _wrapBody(
        Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.shellGradientColors(theme.brightness),
              ),
            ),
            child: scroll,
          ),
        ),
      ),
    );
  }

  /// TabBar da mesa: aba 0 = Compra Rápida (conteúdo existente); aba 1 = Order Book.
  Widget _balcaoMesaComAbas({
    required ThemeData theme,
    required ColorScheme scheme,
    required CatalogStartup mesaStartup,
    required double precoMercadoBrl,
    required Widget tabCompraRapida,
  }) {
    final fid = mesaStartup.firestoreId?.trim() ?? '';
    final tabHeight = MediaQuery.sizeOf(context).height * 0.58;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _mesaTabController,
          labelColor: scheme.primary,
          unselectedLabelColor: AppColors.secondaryLabel(theme),
          indicatorColor: scheme.primary,
          tabs: const [
            Tab(text: 'Compra Rápida'),
            Tab(text: 'Order Book'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: tabHeight,
          child: TabBarView(
            controller: _mesaTabController,
            children: [
              SingleChildScrollView(
                child: tabCompraRapida,
              ),
              fid.isEmpty
                  ? Center(
                      child: Text(
                        'Order Book indisponível para esta startup.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : OrderBookPanel(
                      startupId: fid,
                      startupName: mesaStartup.name,
                      tokenSigla: balcaoTickerParaStartup(mesaStartup),
                      precoOficialBrl: precoMercadoBrl,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  /// Cartões de cotação, botões e gráfico da mesa (cotação ancorada em [precoMercadoBrl]).
  Widget _balcaoMesaTradingColumn({
    required ThemeData theme,
    required ColorScheme scheme,
    required CatalogStartup s,
    required StartupDetailViewData detail,
    required ValueChanged<ValuationPeriod> onPeriodo,
    required VoidCallback comprar,
    required VoidCallback vender,
    required double saldoTokensHeld,
    required String disponivelCarteiraBrlTexto,
    required String totalPosicaoBrlTexto,
    required double precoMercadoBrl,
    BalcaoStartupMarketStats? marketStats,
  }) {
    final now = DateTime.now();
    final precoConhecido = precoMercadoBrl > 1e-9;
    final st = marketStats;
    final serverPts = st?.seriesDiarioPoints;

    List<BalcaoMarketPricePoint>? extendedForStats;
    if (serverPts != null &&
        serverPts.length >= 2 &&
        precoConhecido) {
      extendedForStats = balcaoExtendSeriesToNow(
        balcaoSortAndDedupePoints(serverPts),
        now,
        precoMercadoBrl,
      );
    }
    final stats24 = extendedForStats != null && extendedForStats.length >= 2
        ? balcaoStats24hRolling(extendedForStats)
        : null;

    final cotacao = balcaoCotacaoSeriesForPeriod(
      period: _periodoCotacao,
      nowLocal: now,
      precoMercadoBrl: precoMercadoBrl,
      serverPoints: serverPts,
      detailFallback: detail,
    );

    // Preferir o % da callable (histórico Firestore / mesmo critério do scheduler).
    // O recálculo local pode divergir por interpolação na janela móvel de 24h.
    double? variacao = st?.changePct24h;
    variacao ??= stats24?.changePct24h;
    if (variacao == null && precoConhecido) {
      final diarioSerie = balcaoCotacaoSeriesForPeriod(
        period: ValuationPeriod.diario,
        nowLocal: now,
        precoMercadoBrl: precoMercadoBrl,
        serverPoints: serverPts,
        detailFallback: detail,
      );
      variacao = balcaoVariacao24hPercentual(diarioSerie.valuationMillions);
    }

    String min24h = '—';
    String max24h = '—';
    if (stats24 != null && stats24.minBrl != null && stats24.maxBrl != null) {
      min24h = formatBrl(stats24.minBrl!);
      max24h = formatBrl(stats24.maxBrl!);
    } else if (st != null) {
      if (st.min24hBrl != null) {
        min24h = formatBrl(st.min24hBrl!);
      }
      if (st.max24hBrl != null) {
        max24h = formatBrl(st.max24hBrl!);
      }
    } else if (precoConhecido && cotacao.valuationMillions.length >= 2) {
      final mm = cotacao.valuationMillions;
      min24h = formatBrl(mm.reduce((a, b) => a < b ? a : b));
      max24h = formatBrl(mm.reduce((a, b) => a > b ? a : b));
    }

    final mesaCard = _MesaTokenCard(
      pairLabel: '${balcaoTickerParaStartup(s).toUpperCase()} / BRL',
      nomeStartup: s.name,
      categoria: s.category,
      cotacaoFormatada:
          precoConhecido ? formatBrl(precoMercadoBrl) : '—',
      variacao24hPct: variacao,
      min24h: min24h,
      max24h: max24h,
      saldoTokens: saldoTokensHeld,
      disponivelCarteiraBrlTexto: disponivelCarteiraBrlTexto,
      totalPosicaoBrlTexto: totalPosicaoBrlTexto,
      corLogo: s.logoColor,
      icone: s.logoIcon,
      logoPath: s.logoPath,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        mesaCard,
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: comprar,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  elevation: 2,
                  shadowColor: AppColors.primaryShadow(scheme),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Comprar mercado'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: vender,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.primary,
                  backgroundColor: theme.colorScheme.surface,
                  side: BorderSide(color: scheme.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Vender mercado'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ValuationEvolutionChartCard(
          selected: _periodoCotacao,
          onSelect: onPeriodo,
          series: cotacao,
          primary: scheme.primary,
          title: 'Histórico de cotação',
          formatYAxis: (v) => formatBrl(v),
          formatTooltip: (v) => formatBrl(v),
          touchListenerKey: const ValueKey<String>(
            'balcao_cotacao_chart_touch',
          ),
        ),
      ],
    );
  }
}

/// Seta + logo, como a faixa do [CatalogScreen] (só o wordmark, sem título de startup).
class _BalcaoMesaTopRow extends StatelessWidget {
  const _BalcaoMesaTopRow({required this.onBack});

  final VoidCallback onBack;

  static const _logoHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Trocar startup',
          color: onSurface,
        ),
        MesclaBrandLogo(boxWidth: 200, boxHeight: _logoHeight),
      ],
    );
  }
}

/// Cabeçalho com logo Mescla — mesmo critério visual da [CarteiraScreen].
class _BalcaoLogoHeader extends StatelessWidget {
  const _BalcaoLogoHeader();

  @override
  Widget build(BuildContext context) {
    return const MesclaHeaderRow();
  }
}

/// Card tocável na lista inicial (startup ainda não selecionada).
class _BalcaoStartupRowCard extends StatelessWidget {
  const _BalcaoStartupRowCard({
    required this.startup,
    required this.ticker,
    required this.primary,
    required this.onTap,
  });

  final CatalogStartup startup;
  final String ticker;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
                    // Nome comercial (ex.: Abacate Pay); o ticker fica à direita [ticker].
                    Text(
                      startup.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      startup.category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ticker,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'TOKEN',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartão branco (alinhado a Explorar / detalhe): cotação e saldo com tipografia Neutra.
class _MesaTokenCard extends StatelessWidget {
  const _MesaTokenCard({
    required this.pairLabel,
    required this.nomeStartup,
    required this.categoria,
    required this.cotacaoFormatada,
    required this.variacao24hPct,
    required this.min24h,
    required this.max24h,
    required this.saldoTokens,
    required this.disponivelCarteiraBrlTexto,
    required this.totalPosicaoBrlTexto,
    required this.corLogo,
    required this.icone,
    this.logoPath,
  });

  static const _radius = 22.0;

  /// Tons para mín / máx 24h (máx = verde, mín = vermelho).
  static const _min24hColor = Color(0xFFB91C1C);
  static const _max24hColor = Color(0xFF047857);

  /// Mesmo critério que [balcaoFmtVariacaoPercentualPt] e Carteira (rendimento): verde ↑,
  /// vermelho ↓, texto normal quando ~0 %.
  static Color _corVariacaoPercent24h(ThemeData theme, double pct) {
    if (pct > 0.05) return const Color(0xFF16A34A);
    if (pct < -0.05) return const Color(0xFFDC2626);
    return theme.colorScheme.onSurface;
  }

  final String pairLabel;
  final String nomeStartup;
  final String categoria;
  final String cotacaoFormatada;
  final double? variacao24hPct;
  final String min24h;
  final String max24h;
  final double saldoTokens;
  /// Saldo livre em BRL na carteira simulada (compras à mercado).
  final String disponivelCarteiraBrlTexto;

  /// Posição token × cotação atual (estimativa instantânea para o par).
  final String totalPosicaoBrlTexto;
  final Color corLogo;
  final IconData icone;
  final String? logoPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;

    return Material(
      color: AppColors.themeCardSurface(theme),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(_radius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StartupLogoAvatar(
              logoPath: logoPath,
              fallbackColor: corLogo,
              fallbackIcon: icone,
              size: 52,
              borderRadius: 14,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pairLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.85,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nomeStartup,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    categoria,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.55,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: AppColors.cardDivider(theme)),
                  const SizedBox(height: 12),
                  Text(
                    'COTAÇÃO ATUAL (BRL / TOKEN)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          cotacaoFormatada,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (variacao24hPct != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          '${balcaoFmtVariacaoPercentualPt(variacao24hPct!)}%',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _corVariacaoPercent24h(
                              theme,
                              variacao24hPct!,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Máx. 24h  $max24h',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _max24hColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Mín. 24h  $min24h',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _min24hColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: AppColors.cardDivider(theme)),
                  const SizedBox(height: 12),
                  Text(
                    'Disponível para compras (BRL)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.55,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    disponivelCarteiraBrlTexto,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: AppColors.cardDivider(theme)),
                  const SizedBox(height: 12),
                  Text(
                    'Saldo tokens (posição nesta startup)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatQuantidadeTokensBr(saldoTokens)} tokens',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Total estimado da posição (BRL)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalPosicaoBrlTexto,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w600,
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

/// Uma linha da lista de transações à mercado (compra/venda).
class _TransacaoDiaTile extends StatelessWidget {
  const _TransacaoDiaTile({
    required this.item,
    required this.primary,
    required this.theme,
  });

  final BalcaoTransacaoDia item;
  final Color primary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final tipoLabel = item.tipo == BalcaoOperacaoTipo.compra
        ? 'Compra'
        : 'Venda';
    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipoLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _balcaoLinhaSubtitleExtrato(item),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatBrl(item.valorReais),
              style: theme.textTheme.titleSmall?.copyWith(
                color: primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
