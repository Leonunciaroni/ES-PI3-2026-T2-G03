// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Aba **Balcão** (índice 2 do [MesclaMainShell]): lista de startups pela callable
// `listStartups` (como o Explorar), depois mesa com saldo e histórico reais quando
// há sessão + `firestoreId`, compra/venda à mercado e fluxo quantidade → modal → senha → detalhe (§5.3 MesclaInvest).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../catalog/data/startup_detail_mock.dart';
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

bool _balcaoMesmoDiaLocal(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<BalcaoTransacaoDia> _filtrarTradesLedgerHojePorStartup({
  required QuerySnapshot<Map<String, dynamic>> ledgerSnap,
  required String startupFirestoreId,
  required DateTime agoraLocal,
}) {
  final out = <BalcaoTransacaoDia>[];

  for (final doc in ledgerSnap.docs) {
    final d = doc.data();
    final ts = d['createdAt'];

    DateTime? whenLocal;
    if (ts is Timestamp) {
      whenLocal = ts.toDate();
    }
    if (whenLocal == null || !_balcaoMesmoDiaLocal(whenLocal, agoraLocal)) {
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
  final h = quando.hour.toString().padLeft(2, '0');
  final m = quando.minute.toString().padLeft(2, '0');
  return '${item.resumo} · $h:$m';
}

/// Converte a série de valuation (mock) numa curva de **preço do token em BRL**,
/// ancorada ao [precoAtualBrl] do catálogo (última amostra = cotação atual).
ValuationChartSeries _serieCotacaoTokenBrl(
  ValuationChartSeries valuationSerie,
  double precoAtualBrl,
) {
  final v = valuationSerie.valuationMillions;
  if (v.isEmpty) {
    return ValuationChartSeries(
      valuationMillions: const [],
      sampleTimes: const [],
    );
  }
  final last = v.last;
  if (last.abs() < 1e-9) {
    return ValuationChartSeries(
      valuationMillions: List.filled(v.length, precoAtualBrl),
      sampleTimes: valuationSerie.sampleTimes,
    );
  }
  return ValuationChartSeries(
    valuationMillions: v.map((e) => precoAtualBrl * (e / last)).toList(),
    sampleTimes: valuationSerie.sampleTimes,
  );
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

class _BalcaoTabScreenState extends State<BalcaoTabScreen> {
  late final StartupCatalogFunctionsService _functionsService;

  /// Lista inicial (callable ou future de teste).
  late final Future<List<CatalogStartup>> _listFuture;

  /// Opcional: detalhe enriquecido para o gráfico da mesa quando há `firestoreId`.
  Future<StartupDetailViewData?>? _mesaDetailFuture;

  /// Igual ao [CatalogScreen] — filtra a lista, sem barra de chips de estágio.
  final TextEditingController _searchController = TextEditingController();

  /// Se null, mostramos a **lista**; se preenchido, mostramos a **mesa** dessa startup.
  CatalogStartup? _mesaStartup;

  /// Filtro do gráfico de cotação (mesmos períodos do detalhe da startup).
  ValuationPeriod _periodoCotacao = ValuationPeriod.mensal;

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
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
      _periodoCotacao = ValuationPeriod.mensal;
      _mesaDetailFuture = s.firestoreId != null
          ? _functionsService.fetchStartupDetail(s.firestoreId!)
          : null;
    });
    _jumpBodyScrollTop();
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
      _periodoCotacao = ValuationPeriod.mensal;
      _mesaDetailFuture = null;
    });
    _jumpBodyScrollTop();
  }

  /// Abre o ecrã onde o utilizador define a **quantidade**; o modal e a senha
  /// vêm a seguir nessa mesma cadeia de rotas.
  Future<void> _iniciarFluxoOperacao(BalcaoOperacaoTipo operacao) async {
    final startup = _mesaStartup;
    if (startup == null) return;

    await Navigator.of(context).push<void>(
      MesclaMaterialRoute.fadeSlide<void>(
        (context) =>
            BalcaoQuantidadeTokensScreen(startup: startup, operacao: operacao),
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
      return Column(
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
                  onChanged: (_) => setState(() {}),
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
                    }) {
                      final precoConhecido = mesaStartup.tokenPrice > 1e-9;
                      final totalPosicaoFmt = !carteiraAoVivo
                          ? '—'
                          : !precoConhecido
                              ? '—'
                              : balcaoBrlDisponivel(
                                  saldoTokensEmCarteira *
                                      mesaStartup.tokenPrice,
                                  true,
                                );

                      if (!carteiraAoVivo) {
                        return Column(
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
                              avisoConvidado,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.secondaryLabel(theme),
                              ),
                            ),
                          ],
                        );
                      }

                      return StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>
                      >(
                        stream: SimulatedWalletService.watchLedger(
                          user!.uid,
                          limit: 100,
                        ),
                        builder: (context, ledgerShot) {
                          final txs = ledgerShot.hasData
                              ? _filtrarTradesLedgerHojePorStartup(
                                  ledgerSnap: ledgerShot.data!,
                                  startupFirestoreId: fid!,
                                  agoraLocal: DateTime.now(),
                                )
                              : const <BalcaoTransacaoDia>[];

                          return Column(
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
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'Transações de hoje · mercado',
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (ledgerShot.connectionState ==
                                      ConnectionState.waiting &&
                                  !ledgerShot.hasData)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child:
                                      Center(child: CircularProgressIndicator()),
                                )
                              else if (txs.isEmpty)
                                Text(
                                  'Nenhuma compra ou venda neste par hoje.',
                                  style:
                                      theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        AppColors.secondaryLabel(theme),
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
                          );
                        },
                      );
                    }

                    Widget tradingComCarteiraAoVivo(
                      StartupDetailViewData detail,
                    ) {
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
                              );
                            },
                          );
                        },
                      );
                    }

                    final fut = _mesaDetailFuture;
                    if (!carteiraAoVivo) {
                      final detail = startupDetailFor(mesaStartup);
                      return montarPainelCarteiraStreams(
                        detail: detail,
                        saldoTokensEmCarteira: 0,
                        disponivelBrlFmt: '—',
                        avisoConvidado:
                            'Para ver tokens e extrato ligados ao Balcão, entre com conta e-mail neste equipamento.',
                      );
                    }
                    if (fut == null) {
                      final detail = startupDetailFor(mesaStartup);
                      return tradingComCarteiraAoVivo(detail);
                    }
                    return FutureBuilder<StartupDetailViewData?>(
                      future: fut,
                      builder: (context, snapshot) {
                        final StartupDetailViewData detail =
                            snapshot.hasData && snapshot.data != null
                                ? snapshot.data!
                                : startupDetailFor(mesaStartup);
                        return tradingComCarteiraAoVivo(detail);
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

  /// Cartões de cotação, botões e gráfico da mesa (usa séries reais se a callable devolveu detalhe).
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
  }) {
    final cotacao = _serieCotacaoTokenBrl(
      detail.chartSeriesByPeriod[_periodoCotacao]!,
      s.tokenPrice,
    );
    final diarioBrl = _serieCotacaoTokenBrl(
      detail.chartSeriesByPeriod[ValuationPeriod.diario]!,
      s.tokenPrice,
    );
    final p24 = diarioBrl.valuationMillions;
    final precoConhecido = s.tokenPrice > 1e-9;

    final Widget mesaCard =
        (s.firestoreId != null &&
            FirebaseAuth.instance.currentUser != null)
        ? FutureBuilder<BalcaoStartupMarketStats?>(
            future: SimulatedWalletService.fetchStartupMarketStats(
              s.firestoreId!,
            ),
            builder: (context, statsSnap) {
              double? variacao = balcaoVariacao24hPercentual(p24);
              String min24h = p24.isEmpty
                  ? '—'
                  : formatBrl(p24.reduce((a, b) => a < b ? a : b));
              String max24h = p24.isEmpty
                  ? '—'
                  : formatBrl(p24.reduce((a, b) => a > b ? a : b));
              final st = statsSnap.data;
              if (st != null) {
                variacao = st.changePct24h ?? variacao;
                if (st.min24hBrl != null) {
                  min24h = formatBrl(st.min24hBrl!);
                }
                if (st.max24hBrl != null) {
                  max24h = formatBrl(st.max24hBrl!);
                }
              }
              return _MesaTokenCard(
                pairLabel:
                    '${balcaoTickerParaStartup(s).toUpperCase()} / BRL',
                nomeStartup: s.name,
                categoria: s.category,
                cotacaoFormatada:
                    precoConhecido ? formatBrl(s.tokenPrice) : '—',
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
            },
          )
        : _MesaTokenCard(
            pairLabel: '${balcaoTickerParaStartup(s).toUpperCase()} / BRL',
            nomeStartup: s.name,
            categoria: s.category,
            cotacaoFormatada: precoConhecido ? formatBrl(s.tokenPrice) : '—',
            variacao24hPct: balcaoVariacao24hPercentual(p24),
            min24h: p24.isEmpty
                ? '—'
                : formatBrl(p24.reduce((a, b) => a < b ? a : b)),
            max24h: p24.isEmpty
                ? '—'
                : formatBrl(p24.reduce((a, b) => a > b ? a : b)),
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
        Text(
          'Ordem à mercado · execução imediata pela cotação publicada.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.secondaryLabel(theme),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        mesaCard,
        const SizedBox(height: 18),
        Text(
          'Comprar usa o disponível na carteira; vender debita apenas desta startup.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.secondaryLabel(theme),
            fontWeight: FontWeight.w500,
          ),
        ),
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
          footnote: '',
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
                    Text(
                      startup.sigla ?? startup.name,
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

  /// Tons discretos para variação (evitam o visual “casa de apostas”).
  static const _acimaRef = Color(0xFF047857);
  static const _abaixoRef = Color(0xFF4B5563);

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
                          '${variacao24hPct! >= 0 ? '+' : ''}${variacao24hPct!.toStringAsFixed(2)}%'
                              .replaceAll('.', ','),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: variacao24hPct! >= 0
                                ? _acimaRef
                                : _abaixoRef,
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
                            color: AppColors.secondaryLabel(theme),
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
                            color: AppColors.secondaryLabel(theme),
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

/// Uma linha da lista “transações do dia”.
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
