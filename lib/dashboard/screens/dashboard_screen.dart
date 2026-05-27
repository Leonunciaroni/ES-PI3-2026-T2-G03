// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Dashboard — Início com dados reais (`sim_wallet`, catálogo,
// `getStartupMarketStats`). Barras mensais refletem **saldo BRL disponível**
// ao fecho reconstruído pelo extrato; o grande valor no card roxo é o
// **patrimônio total** (caixa + mercado das startups).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/services/user_firestore_service.dart';
import '../../auth/services/session_persistence_service.dart';
import '../../balcao/screens/balcao_tab_screen.dart';
import '../../carteira/carteira_patrimonio_metrics.dart';
import '../../carteira/invested_startup_position_math.dart';
import '../../carteira/models/carteira_invested_position_model.dart';
import '../../carteira/screens/carteira_screen.dart';
import '../../carteira/services/simulated_wallet_service.dart';
import '../../carteira/widgets/invested_startup_card.dart';
import '../../catalog/data/startup_detail_mock.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../catalog/screens/catalog_screen.dart';
import '../../catalog/services/startup_catalog_functions_service.dart';
import '../../catalog/services/startup_catalog_list_cache.dart';
import '../../catalog/services/startup_logo_precache_service.dart';
import '../../navigation/mescla_navigation.dart';
import '../../navigation/mescla_tab_count.dart';
import '../../perfil/screens/perfil_screen.dart';
import '../dashboard_monthly_saldo_bars.dart';
import '../widgets/dashboard_hero_monthly_saldo_bars.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mescla_header_row.dart';
import '../../widgets/mescla_main_shell.dart' show MesclaMainShell;

// --- Helpers de período temporal (mesma lógica que [saldoBrlEvolucaoSeries] na Carteira) -----
DateTime _dashInicioDiaLocal(DateTime now) =>
    DateTime(now.year, now.month, now.day);

DateTime _dashInicioJanelaDeslizante(DateTime now, int dias) {
  final sod = _dashInicioDiaLocal(now);
  return sod.subtract(Duration(days: dias));
}

DateTime _dashInicioPeriodoValuationChip(ValuationPeriod p, DateTime now) {
  switch (p) {
    case ValuationPeriod.diario:
      return _dashInicioDiaLocal(now);
    case ValuationPeriod.semanal:
      return _dashInicioJanelaDeslizante(now, 7);
    case ValuationPeriod.mensal:
      return _dashInicioJanelaDeslizante(now, 30);
    case ValuationPeriod.seisMeses:
      return _dashInicioJanelaDeslizante(now, 180);
    case ValuationPeriod.ytd:
      return DateTime(now.year, 1, 1);
  }
}

List<DateTime> _dashAmostrasTempoEntre({
  required DateTime inicio,
  required DateTime fim,
  int pontos = 7,
}) {
  assert(pontos >= 2);
  final a = inicio.millisecondsSinceEpoch;
  final b = fim.millisecondsSinceEpoch;
  if (b <= a) {
    return <DateTime>[
      inicio,
      fim.isAfter(inicio) ? fim : inicio.add(const Duration(seconds: 1)),
    ];
  }
  final out = <DateTime>[];
  for (var i = 0; i < pontos; i++) {
    final t = a + ((b - a) * i / (pontos - 1)).round();
    out.add(DateTime.fromMillisecondsSinceEpoch(t));
  }
  return out;
}

CatalogStartup? _dashCatalogMatchParaPosicaoDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  Map<String, CatalogStartup> byFirestoreId,
) {
  final m = doc.data();
  final sid = doc.id.trim().isNotEmpty
      ? doc.id
      : ((m['startupId'] as String?) ?? '').trim();
  if (sid.isEmpty) return null;
  return byFirestoreId[sid];
}

double _dashSomaValorMercadoPosicoes(
  QuerySnapshot<Map<String, dynamic>> snap,
  Map<String, CatalogStartup> porFirestoreId,
) {
  var sum = 0.0;
  for (final doc in snap.docs) {
    final match = _dashCatalogMatchParaPosicaoDoc(doc, porFirestoreId);
    final held = (doc.data()['tokensHeld'] as num?)?.toDouble() ?? 0.0;
    final px = match?.tokenPrice ?? 0.0;
    if (px > 1e-9 && held.isFinite && held >= 0) {
      sum += held * px;
    } else {
      sum += (doc.data()['costBasisBrl'] as num?)?.toDouble() ?? 0.0;
    }
  }
  return sum;
}

/// Tela inicial do app no modo dev: patrimônio, resumo e lista de startups.
///
/// O ícone de olho apenas oculta valores sensíveis localmente ([setState]).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.initialMainNavIndex = 0})
    : assert(
        initialMainNavIndex >= 0 && initialMainNavIndex < kMesclaMainTabCount,
      );

  /// Índice inicial da barra inferior (uso puntual e.g. deeplink ao Balcão).
  /// Após login o fluxo normal usa sempre 0 — Início.
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

  /// Abas já ativadas pelo utilizador (ou por deeplink) desde que o shell abriu.
  /// As não ativadas ficam leves para reduzir custo de arranque.
  final Set<int> _activatedMainTabs = <int>{0};

  /// Cache de `getStartupMarketStats` no mesmo intervalo que a Carteira (~2 min).
  Future<Map<String, BalcaoStartupMarketStats?>>? _dashboardMarketStatsFuture;
  String _dashboardMarketStatsCacheKey = '';

  /// Cliente HTTP para `listStartups` (logos e metadados das posições).
  late final StartupCatalogFunctionsService _catalogService;

  /// Igual à Carteira: expande lista além de 3 cards.
  bool _startupsDashboardVerTodas = false;

  /// Cache do primeiro nome na saudação (evita novo Future a cada rebuild).
  String? _saudacaoPrimeiroNomeUid;
  Future<String>? _saudacaoPrimeiroNomeFuture;

  /// Período fixo do sparkline alinhado ao chip **Mensal** da Carteira (30 dias deslizantes).
  static const ValuationPeriod _periodoSparklineStartups = ValuationPeriod.mensal;

  static const _horizontalPadding = 20.0;
  static const _sectionGap = 24.0;

  /// Pulso para a [CarteiraScreen] descer até «Minhas Startups Investidas» (botão Ver todas no Início).
  final ValueNotifier<int> _carteiraScrollStartupsTick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _catalogService = StartupCatalogFunctionsService();
    WidgetsBinding.instance.addObserver(this);
    _mainNavIndex = widget.initialMainNavIndex.clamp(
      0,
      kMesclaMainTabCount - 1,
    );
    _activatedMainTabs.add(_mainNavIndex);
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      MesclaNavigationPrefetch.scheduleWalletFirestoreForCarteiraTab(u.uid);
    }
    // Primeiro quadro garante [mounted] antes de usar [precacheImage] nos logos do catálogo.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _preloadCatalogLogoBitmaps(),
    );
  }

  @override
  void dispose() {
    _carteiraScrollStartupsTick.dispose();
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
    StartupCatalogListCache.instance.fullList(_catalogService).then((
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
      _activatedMainTabs.add(2);
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
    setState(() {
      _mainNavIndex = i;
      _activatedMainTabs.add(i);
    });
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

  /// Pré-busca igual à Carteira das séries intradiárias usadas pelo sparkline direito dos cards.
  Future<Map<String, BalcaoStartupMarketStats?>> _dashboardMarketStatsForInvestidasDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docsPosicao,
  ) {
    final bucket = DateTime.now().millisecondsSinceEpoch ~/ 120000;
    final ids = docsPosicao.map((d) => d.id.trim()).where((s) => s.isNotEmpty).toList()
      ..sort();
    final key = '$bucket|${ids.join('|')}';
    if (_dashboardMarketStatsFuture != null &&
        _dashboardMarketStatsCacheKey == key) {
      return _dashboardMarketStatsFuture!;
    }
    _dashboardMarketStatsCacheKey = key;
    if (ids.isEmpty) {
      _dashboardMarketStatsFuture =
          Future<Map<String, BalcaoStartupMarketStats?>>.value({});
      return _dashboardMarketStatsFuture!;
    }
    _dashboardMarketStatsFuture =
        Future.wait(ids.map(SimulatedWalletService.fetchStartupMarketStats)).then(
      (lista) {
        final m = <String, BalcaoStartupMarketStats?>{};
        for (var i = 0; i < ids.length; i++) {
          m[ids[i]] = lista[i];
        }
        return m;
      },
    );
    return _dashboardMarketStatsFuture!;
  }

  String _painelEtiquetaTemporalSaudacaoCaps() {
    final agoraRelogio = DateTime.now();
    return switch (agoraRelogio.hour) {
      < 12 => 'BOM DIA',
      < 18 => 'BOA TARDE',
      _ => 'BOA NOITE',
    };
  }

  /// Primeiro nome em caps só com dados já em memória (Auth), antes do Firestore regressar.
  String? _primeiroNomeSaudacaoSync(User user) {
    final nomeAuth = user.displayName?.trim();
    if (nomeAuth != null && nomeAuth.isNotEmpty) {
      return nomeAuth.split(RegExp(r'\s+')).first.toUpperCase();
    }
    final localEmail = user.email?.split('@').first.trim();
    if (localEmail != null && localEmail.isNotEmpty) {
      return localEmail.toUpperCase();
    }
    return null;
  }

  Future<String> _resolverPrimeiroNomeSaudacaoCaps(User user) async {
    var nomeBruto = user.displayName?.trim();
    if (nomeBruto == null || nomeBruto.isEmpty) {
      nomeBruto = await UserFirestoreService.fetchNameFromFirestore(user.uid);
    }
    if (nomeBruto == null || nomeBruto.isEmpty) {
      nomeBruto = user.email?.split('@').first.trim();
    }
    if (nomeBruto == null || nomeBruto.isEmpty) {
      return 'INVESTIDOR';
    }
    return nomeBruto.split(RegExp(r'\s+')).first.toUpperCase();
  }

  Future<String> _ensurePrimeiroNomeSaudacaoFuture(User user) {
    if (_saudacaoPrimeiroNomeUid != user.uid ||
        _saudacaoPrimeiroNomeFuture == null) {
      _saudacaoPrimeiroNomeUid = user.uid;
      _saudacaoPrimeiroNomeFuture = _resolverPrimeiroNomeSaudacaoCaps(user);
    }
    return _saudacaoPrimeiroNomeFuture!;
  }

  Widget _painelTituloSaudacao(TextStyle? labelCaps, User user) {
    final etiquetaTemporal = _painelEtiquetaTemporalSaudacaoCaps();
    return FutureBuilder<String>(
      future: _ensurePrimeiroNomeSaudacaoFuture(user),
      builder: (context, snap) {
        final primeiro = snap.hasData
            ? snap.data!
            : (_primeiroNomeSaudacaoSync(user) ?? '…');
        return Text('$etiquetaTemporal, $primeiro', style: labelCaps);
      },
    );
  }

  Widget _buildHomeTab(
    ThemeData theme,
    TextStyle? labelCaps,
    ColorScheme colorScheme,
    Color onSurface,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final principal = colorScheme.primary;

    if (uid == null || user == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _horizontalPadding,
          8,
          _horizontalPadding,
          16,
        ),
        child: Text(
          'Sessão indisponível — faça login novamente pelo menu Perfil.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, limitacoesPainelAscendente) {
        final larguraGrafHero =
            (limitacoesPainelAscendente.maxWidth - _horizontalPadding * 2) *
                0.62;

        Widget envolverBarrasFinanceirasMes(Widget graficoBarrasFinanceirasMes) =>
            SizedBox(
              width: larguraGrafHero.clamp(180.0, 368.0),
              child: graficoBarrasFinanceirasMes,
            );

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
              const MesclaHeaderRow(),
              const SizedBox(height: 20),
              _painelTituloSaudacao(labelCaps, user),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Seu patrimônio',
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
                    tooltip:
                        _hideValues ? 'Mostrar valores' : 'Ocultar valores',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<double>(
                stream: SimulatedWalletService.watchBrlBalance(uid),
                builder: (context, balSnap) {
                  final erroBalanco = balSnap.hasError;
                  final brlCorrente = (!balSnap.hasData || erroBalanco)
                      ? 0.0
                      : (balSnap.data ?? 0.0);

                  if (balSnap.connectionState == ConnectionState.waiting &&
                      !balSnap.hasData &&
                      !erroBalanco) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: SimulatedWalletService.watchLedgerRecentForChart(
                      uid,
                      limit: 2000,
                    ),
                    builder: (context, ledSnap) {
                      final erroExtrato = ledSnap.hasError;
                      final linhasExtrato =
                          ledSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      final movimentosAsc =
                          ledSnap.hasData && ledSnap.data != null
                              ? carteiraParseLedgerTradesAscending(ledSnap.data!)
                              : const <CarteiraLedgerTradeRow>[];

                      if (ledSnap.connectionState == ConnectionState.waiting &&
                          !ledSnap.hasData &&
                          !erroExtrato) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: SimulatedWalletService.watchPositions(uid),
                        builder: (context, posSnap) {
                          final erroPosicoes = posSnap.hasError;
                          final documentosPosicao =
                              posSnap.data?.docs ??
                              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                          if (posSnap.connectionState ==
                                  ConnectionState.waiting &&
                              !posSnap.hasData &&
                              !erroPosicoes) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          return FutureBuilder<List<CatalogStartup>>(
                            future: StartupCatalogListCache.instance
                                .fullList(_catalogService),
                            builder: (context, catSnap) {
                              if (catSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !catSnap.hasData &&
                                  catSnap.error == null) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 48),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final catalogoBruto = catSnap.hasError
                                  ? const <CatalogStartup>[]
                                  : (catSnap.data ?? const <CatalogStartup>[]);
                              final mapaCatalogoPorId =
                                  <String, CatalogStartup>{};
                              for (final s in catalogoBruto) {
                                final fid = s.firestoreId?.trim();
                                if (fid != null && fid.isNotEmpty) {
                                  mapaCatalogoPorId[fid] = s;
                                }
                              }

                              final somaValorMercadoStartups =
                                  (!erroPosicoes && posSnap.hasData)
                                      ? _dashSomaValorMercadoPosicoes(
                                          posSnap.data!,
                                          mapaCatalogoPorId,
                                        )
                                      : 0.0;

                              final patrimonioConsolidado =
                                  carteiraPatrimonioTotal(
                                brlDisponivel: brlCorrente,
                                valorMercadoPosicoes: somaValorMercadoStartups,
                              );

                              final etiquetaVariacaoMensal = _hideValues
                                  ? '• • • • • •'
                                  : (erroBalanco || erroExtrato
                                      ? 'N/D este mês'
                                      : carteiraVariacaoSaldoMesLabel(
                                          brlNow: brlCorrente,
                                          docsNewestFirst: linhasExtrato,
                                          now: DateTime.now(),
                                        ));

                              final serieBarrasMensais =
                                  dashboardMontarBarrasUltimosMesesSaldo(
                                agoraRelogio: DateTime.now(),
                                brlSaldoCorrente: brlCorrente,
                                ledgerDesc: linhasExtrato,
                                numeroMeses: 12,
                              );

                              final graficoMiniSaldoMensal = _hideValues
                                  ? const SizedBox.shrink()
                                  : envolverBarrasFinanceirasMes(
                                      DashboardHeroMonthlySaldoBars(
                                        series: serieBarrasMensais,
                                        formatarBr: _money,
                                      ),
                                    );

                              final quantidadeStartupsAtivas =
                                  documentosPosicao.length;

                              final permiteExpandirListaStartupsPainelTopo =
                                  quantidadeStartupsAtivas > 3;

                              final listaVerticalSuperiorPainelTopo =
                                  <Widget>[
                                _HeroCard(
                                  gradient: _heroGradient,
                                  totalLabel: 'SALDO TOTAL INVESTIDO',
                                  totalValue: (erroBalanco || erroPosicoes)
                                      ? '—'
                                      : _money(patrimonioConsolidado),
                                  trendText: etiquetaVariacaoMensal,
                                  graficoBarrasMensais: graficoMiniSaldoMensal,
                                  reservaEspacoMiniGrafico: !_hideValues,
                                ),
                                const SizedBox(height: _sectionGap),
                                _SummaryCard(
                                  background: AppColors.themeMutedSurface(theme),
                                  icon: Icon(
                                    Icons.rocket_launch_outlined,
                                    color: colorScheme.primary,
                                    size: 28,
                                  ),
                                  title: erroPosicoes
                                      ? '—'
                                      : '$quantidadeStartupsAtivas startups',
                                  subtitle: quantidadeStartupsAtivas == 1
                                      ? 'No portfólio ativo'
                                      : 'No portfólio ativo',
                                ),
                                const SizedBox(height: 12),
                                _SummaryCard(
                                  background:
                                      AppColors.themeMutedSurface(theme),
                                  icon: Icon(
                                    Icons.trending_up_outlined,
                                    color: _walletIconColor,
                                    size: 28,
                                  ),
                                  title: erroPosicoes
                                      ? '—'
                                      : _money(somaValorMercadoStartups),
                                  subtitle:
                                      'Valor em startups no preço atual (mercado)',
                                ),
                                const SizedBox(height: _sectionGap),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Minhas startups',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: onSurface,
                                        ),
                                      ),
                                    ),
                                    if (permiteExpandirListaStartupsPainelTopo)
                                      TextButton(
                                        onPressed: () => setState(
                                          () =>
                                              _startupsDashboardVerTodas =
                                                  !_startupsDashboardVerTodas,
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          _startupsDashboardVerTodas
                                              ? 'Ver menos'
                                              : 'Ver mais',
                                          style:
                                              theme.textTheme.labelLarge
                                                  ?.copyWith(
                                                color: principal,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    TextButton(
                                      onPressed: () {
                                        final user =
                                            FirebaseAuth.instance.currentUser;
                                        if (user != null) {
                                          MesclaNavigationPrefetch
                                              .scheduleWalletFirestoreForCarteiraTab(
                                            user.uid,
                                          );
                                        }
                                        setState(() {
                                          _mainNavIndex = 1;
                                          _activatedMainTabs.add(1);
                                        });
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          _carteiraScrollStartupsTick.value++;
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        padding:
                                            const EdgeInsets.only(left: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Ver todas',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          color: principal,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ];

                              if (erroPosicoes) {
                                listaVerticalSuperiorPainelTopo.add(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      'Não foi possível carregar as posições (${posSnap.error}).',
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                            color: AppColors.secondaryLabel(
                                              theme,
                                            ),
                                          ),
                                    ),
                                  ),
                                );
                              } else if (quantidadeStartupsAtivas == 0) {
                                listaVerticalSuperiorPainelTopo.add(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: Text(
                                      'Ainda não há startups investidas. '
                                      'Adicione saldo pela Carteira e negocie no Balcão.',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                            color: AppColors.secondaryLabel(
                                              theme,
                                            ),
                                            height: 1.45,
                                          ),
                                    ),
                                  ),
                                );
                              } else {
                                final posicoesVisiveisPainelTopo =
                                    _startupsDashboardVerTodas ||
                                            quantidadeStartupsAtivas <= 3
                                        ? documentosPosicao
                                        : documentosPosicao.take(3).toList();

                                final agoraGrafSparkPainelTopo =
                                    DateTime.now();
                                final instanteHistoricoMesPainelTopo =
                                    _dashInicioPeriodoValuationChip(
                                  _periodoSparklineStartups,
                                  agoraGrafSparkPainelTopo,
                                );
                                final amostrasPontosTemporalPainelTopo =
                                    _dashAmostrasTempoEntre(
                                  inicio: instanteHistoricoMesPainelTopo,
                                  fim: agoraGrafSparkPainelTopo,
                                  pontos: 7,
                                );

                                listaVerticalSuperiorPainelTopo.add(
                                  FutureBuilder<
                                      Map<String, BalcaoStartupMarketStats?>>(
                                    future:
                                        _dashboardMarketStatsForInvestidasDocs(
                                      posicoesVisiveisPainelTopo,
                                    ),
                                    builder: (context, mktFutPainelTopo) {
                                      final Map<String,
                                              BalcaoStartupMarketStats?>
                                          mapaMercadoPainelTopo =
                                          mktFutPainelTopo.data ??
                                              const <
                                                  String,
                                                  BalcaoStartupMarketStats?
                                              >{};

                                      final widgetsCartoesPainelTopo =
                                          <Widget>[];

                                      for (final docPosPainelTopo
                                          in posicoesVisiveisPainelTopo) {
                                        final matchCatalogoPainelTopo =
                                            _dashCatalogMatchParaPosicaoDoc(
                                          docPosPainelTopo,
                                          mapaCatalogoPorId,
                                        );
                                        final modeloInvestPainelTopo =
                                            mapFirestorePosicaoParaInvestida(
                                          docPosPainelTopo,
                                          catalogMatch:
                                              matchCatalogoPainelTopo,
                                        );
                                        final custoPainelTopo =
                                            (docPosPainelTopo
                                                    .data()['costBasisBrl']
                                                    as num?)
                                                    ?.toDouble() ??
                                                0.0;
                                        final heldPainelTopo =
                                            (docPosPainelTopo
                                                    .data()['tokensHeld']
                                                    as num?)
                                                    ?.toDouble() ??
                                                0.0;
                                        final cotacaoPainelTopo =
                                            matchCatalogoPainelTopo
                                                    ?.tokenPrice ??
                                                0.0;

                                        final tonRendPainelTopo =
                                            carteiraYieldTone(
                                          costBasisBrl: custoPainelTopo,
                                          tokensHeld: heldPainelTopo,
                                          tokenPriceBrl: cotacaoPainelTopo,
                                        );

                                        final mercadoPainelTopo =
                                            (cotacaoPainelTopo > 1e-9 &&
                                                    heldPainelTopo.isFinite &&
                                                    heldPainelTopo >= 0)
                                                ? heldPainelTopo *
                                                    cotacaoPainelTopo
                                                : null;

                                        final serieMercadoPainelTopo =
                                            mapaMercadoPainelTopo[
                                                docPosPainelTopo.id.trim()];

                                        final sparkPainelTopo =
                                            carteiraSingleStartupSparklineValues(
                                          movimentosAsc,
                                          startupId:
                                              docPosPainelTopo.id,
                                          fallbackPriceBrl:
                                              cotacaoPainelTopo,
                                          sampleTimes:
                                              amostrasPontosTemporalPainelTopo,
                                          tokensHeldNowFromDoc:
                                              heldPainelTopo,
                                          marketPriceSeries:
                                              serieMercadoPainelTopo
                                                  ?.seriesDiarioPoints,
                                          anchorNow:
                                              agoraGrafSparkPainelTopo,
                                        );

                                        String textoValorMercadoInvestivoTopo;
                                        if (mercadoPainelTopo == null ||
                                            !mercadoPainelTopo.isFinite) {
                                          textoValorMercadoInvestivoTopo = '—';
                                        } else if (_hideValues) {
                                          textoValorMercadoInvestivoTopo =
                                              'R\$ ••••••';
                                        } else {
                                          textoValorMercadoInvestivoTopo =
                                              _money(mercadoPainelTopo);
                                        }

                                        widgetsCartoesPainelTopo.addAll([
                                          InvestedStartupCard(
                                            startup:
                                                modeloInvestPainelTopo.toInvestedRowUi(),
                                            primary: principal,
                                            hideValues: _hideValues,
                                            rendimentoExibicao: _percent(
                                              modeloInvestPainelTopo
                                                  .rendimentoLabel,
                                            ),
                                            investidoExibicao:
                                                _money(custoPainelTopo),
                                            valorAtualExibicao:
                                                textoValorMercadoInvestivoTopo,
                                            sparklineValues: sparkPainelTopo,
                                            rendimentoTone:
                                                tonRendPainelTopo,
                                          ),
                                          const SizedBox(height: 12),
                                        ]);
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: widgetsCartoesPainelTopo,
                                      );
                                    },
                                  ),
                                );
                              }

                              listaVerticalSuperiorPainelTopo
                                  .add(const SizedBox(height: 8));
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: listaVerticalSuperiorPainelTopo,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
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
        _activatedMainTabs.contains(1)
            ? CarteiraScreen(
                // Força novo [State] após migração do período do gráfico para [ValuationPeriod]
                // (evita crash de tipo com hot reload / estado preso no [IndexedStack]).
                key: const ValueKey<String>('carteira_valuation_period'),
                wrapWithSafeArea: false,
                scrollStartupsSectionTick: _carteiraScrollStartupsTick,
                onCompraVendaTokens: () => setState(() {
                  _mainNavIndex = 2;
                  _activatedMainTabs.add(2);
                }), // Balcão
              )
            : const SizedBox.shrink(),
        _activatedMainTabs.contains(2)
            ? BalcaoTabScreen(
                key: ValueKey<int>(_balcaoNavCount),
                wrapWithSafeArea: false,
                initialMesaStartup: _balcaoStartup,
              )
            : const SizedBox.shrink(),
        _activatedMainTabs.contains(3)
            ? CatalogScreen(
                wrapWithSafeArea: false,
                onInvestir: _abrirBalcaoParaStartup,
              )
            : const SizedBox.shrink(),
        _activatedMainTabs.contains(4)
            ? PerfilScreen(
                wrapWithSafeArea: false,
                onInvestir: _abrirBalcaoParaStartup,
              )
            : const SizedBox.shrink(),
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
    required this.graficoBarrasMensais,
    this.reservaEspacoMiniGrafico = true,
  });

  final Gradient gradient;
  final String totalLabel;
  final String totalValue;
  final String trendText;

  /// Evolução mensal do saldo BRL (mesma base do extrato). Pode ser `SizedBox.shrink()`.
  final Widget graficoBarrasMensais;

  /// Quando `false` (valores ocultos), não reserva altura vaga sob o badge para o mini-gráfico.
  final bool reservaEspacoMiniGrafico;

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
              SizedBox(height: reservaEspacoMiniGrafico ? 100 : 12),
            ],
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: graficoBarrasMensais,
          ),
        ],
      ),
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
