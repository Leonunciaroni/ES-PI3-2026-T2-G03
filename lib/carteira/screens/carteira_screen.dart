// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
// Contribuição: Miguel Fernandes Costacurta — RA: 25003110. Carteira real via Firestore e gráfico de saldo.
//
// Tela **Carteira** — protótipo visual alinhado ao Figma (património, evolução,
// startups investidas, movimentações). Com utilizador autenticado, saldo BRL,
// posições e extrato vêm do Firestore (`sim_wallet`); convidado mantém mocks.
// Inclui **Minhas Chaves PIX** (Firestore em `users/{uid}` se logado; memória
// se convidado) e atalho **Sacar** (fluxo visual).
//
// Pré-carga: ao mudar para este separador no dashboard, [MesclaNavigationPrefetch]
// dispara leituras em paralelo (ver `lib/navigation/mescla_navigation.dart`) para
// aquecer a cache antes dos [StreamBuilder]s — melhora a perceção de velocidade.
//
// [wrapWithSafeArea]: quando um pai (ex.: [MesclaMainShell]) já aplicou
// [SafeArea], passa `false` para não duplicar insets no topo.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/services/user_firestore_service.dart';
import '../../catalog/data/startup_detail_mock.dart';
// Catálogo (`listStartups` via cache): cruzar posições Firestore com `firestoreId`
// para logo em Storage/URL e metadados — mesmo critério que Explorar/Balcão.
import '../../catalog/models/catalog_startup.dart';
import '../../catalog/services/startup_catalog_functions_service.dart';
import '../../catalog/services/startup_catalog_list_cache.dart';
import '../../navigation/mescla_material_route.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brazil_flag_icon.dart';
import '../../widgets/mescla_header_row.dart';
import '../../widgets/mescla_period_pill_chip.dart';
import '../../widgets/valuation_evolution_chart_card.dart';
import '../format/carteira_brl.dart';
import '../format/pix_chave_input.dart';
import '../invested_startup_position_math.dart';
import '../models/carteira_invested_position_model.dart';
import '../models/carteira_movimentacao_detalhe.dart';
import '../models/pix_chave_ui.dart';
import '../carteira_patrimonio_metrics.dart';
import '../services/simulated_wallet_service.dart';
import '../widgets/invested_startup_card.dart';
import 'adicionar_fundos_screen.dart';
import 'carteira_movimentacao_detalhe_screen.dart';
import 'sacar_valor_screen.dart';

// --- Série “Evolução do património” (R$) — alinhada ao [ValuationEvolutionChartCard] ----
//
// Regras de produto aqui: (1) o gráfico da carteira é **património total** (saldo BRL
// disponível + valor de mercado das posições em tokens); (2) os chips de período
// usam janelas **deslizantes** (7 / 30 / 180 dias), **hoje** e **YTD**, ver
// [_carteiraInicioPeriodo].

/// Início do **dia civil** local (00:00).
DateTime _carteiraInicioDiaLocal(DateTime now) =>
    DateTime(now.year, now.month, now.day);

/// Início da janela **deslizante** de [dias] dias civis (00:00 local há [dias] dias).
DateTime _carteiraInicioJanelaDeslizante(DateTime now, int dias) {
  final sod = _carteiraInicioDiaLocal(now);
  return sod.subtract(Duration(days: dias));
}

List<DateTime> _carteiraAmostrasTempoEntre({
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

List<DateTime> _carteiraSampleTimesRelativos(ValuationPeriod p, DateTime now) {
  final inicio = _carteiraInicioPeriodo(p, now);
  return _carteiraAmostrasTempoEntre(inicio: inicio, fim: now);
}

/// Série de saldo (valores em **reais**; campo reutiliza o mock [ValuationChartSeries]).
ValuationChartSeries carteiraSaldoSeries(ValuationPeriod p, [DateTime? agora]) {
  final now = agora ?? DateTime.now();
  // Curvas suaves e monótonas (evita “dentes” de segmentos retos com ruído).
  List<double> brl;
  switch (p) {
    case ValuationPeriod.diario:
      brl = [10200, 10350, 10500, 10800, 11050, 11600, 12050];
    case ValuationPeriod.semanal:
      brl = [9200, 9600, 10100, 10500, 11000, 11500, 12000];
    case ValuationPeriod.mensal:
      brl = [8500, 9000, 9600, 10200, 10800, 11500, 12450];
    case ValuationPeriod.seisMeses:
      brl = [6500, 7200, 8000, 9000, 10000, 11000, 12050];
    case ValuationPeriod.ytd:
      brl = [6200, 7000, 8000, 9000, 10000, 11000, 12050];
  }
  return ValuationChartSeries(
    valuationMillions: brl.map((e) => e.toDouble()).toList(),
    sampleTimes: _carteiraSampleTimesRelativos(p, now),
  );
}

/// Início da janela temporal de cada chip do gráfico (inclusivo):
/// - **DIÁRIO**: dia civil corrente (desde 00:00 local até agora).
/// - **SEMANAL**: últimos 7 dias (desde 00:00 local há 7 dias).
/// - **MENSAL**: últimos 30 dias (desde 00:00 local há 30 dias).
/// - **6 MESES**: últimos 180 dias (desde 00:00 local há 180 dias).
/// - **YTD**: 1 de janeiro do ano corrente (00:00 local).
DateTime _carteiraInicioPeriodo(ValuationPeriod p, DateTime now) {
  switch (p) {
    case ValuationPeriod.diario:
      return _carteiraInicioDiaLocal(now);
    case ValuationPeriod.semanal:
      return _carteiraInicioJanelaDeslizante(now, 7);
    case ValuationPeriod.mensal:
      return _carteiraInicioJanelaDeslizante(now, 30);
    case ValuationPeriod.seisMeses:
      return _carteiraInicioJanelaDeslizante(now, 180);
    case ValuationPeriod.ytd:
      return DateTime(now.year, 1, 1);
  }
}

/// Série temporal do **saldo BRL disponível**, coerente com o ledger e [brlNow].
/// Usada como base para [carteiraPatrimonioEvolucaoSeries] (soma valor de mercado das posições).
///
/// O intervalo temporal vem de [_carteiraInicioPeriodo] (alinhado aos chips §5.4).
/// Pontos no tempo = início da janela, cada `createdAt` do ledger no intervalo, e “agora”.
ValuationChartSeries saldoBrlEvolucaoSeries({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docsNewestFirst,
  required ValuationPeriod periodo,
  required DateTime now,
  required double brlNow,
}) {
  final inicio = _carteiraInicioPeriodo(periodo, now);
  final brlOpening = carteiraBrlAntesDoIntervalo(
    brlNow: brlNow,
    docsNewestFirst: docsNewestFirst,
    rangeStartInclusive: inicio,
    rangeEndInclusive: now,
  );

  final inPeriodChrono = docsNewestFirst.reversed.where((d) {
    final ts = d.data()['createdAt'];
    if (ts is! Timestamp) return false;
    final t = ts.toDate();
    return !t.isBefore(inicio) && !t.isAfter(now);
  }).toList();

  final times = <DateTime>[inicio];
  final values = <double>[brlOpening];
  var b = brlOpening;

  for (final d in inPeriodChrono) {
    final m = d.data();
    final ts = m['createdAt'];
    if (ts is! Timestamp) continue;
    final t = ts.toDate();
    b += carteiraDeltaBrlLedgerLinha(m);
    times.add(t);
    values.add(b);
  }

  if (times.length < 2) {
    times.add(now);
    values.add(brlNow);
  } else if (times.last.isBefore(now)) {
    times.add(now);
    values.add(brlNow);
  } else {
    values[values.length - 1] = brlNow;
  }

  return ValuationChartSeries(
    valuationMillions: values,
    sampleTimes: times,
  );
}

/// Evolução do **património total** (BRL disponível + valor de mercado das posições)
/// nos mesmos instantes que [saldoBrlEvolucaoSeries].
ValuationChartSeries carteiraPatrimonioEvolucaoSeries({
  required ValuationChartSeries serieSaldoBrl,
  required List<CarteiraLedgerTradeRow> tradesAsc,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> positionDocs,
  required Map<String, CatalogStartup> catalogByFirestoreId,
  required Map<String, BalcaoStartupMarketStats?> marketStatsByStartupId,
  required DateTime now,
}) {
  final times = serieSaldoBrl.sampleTimes;
  final brlVals = serieSaldoBrl.valuationMillions;
  final out = <double>[];
  for (var i = 0; i < times.length; i++) {
    var mvTotal = 0.0;
    for (final doc in positionDocs) {
      final sid = doc.id.trim();
      if (sid.isEmpty) continue;
      final held =
          (doc.data()['tokensHeld'] as num?)?.toDouble() ?? 0.0;
      final match = catalogByFirestoreId[sid];
      final pxCat = match?.tokenPrice ?? 0.0;
      final st = marketStatsByStartupId[sid];
      mvTotal += carteiraValorMercadoPosicaoNumInstante(
        tradesAsc: tradesAsc,
        startupId: sid,
        instant: times[i],
        fallbackCatalogPriceBrl: pxCat,
        tokensHeldNowFromDoc: held,
        marketSeriesDiario: st?.seriesDiarioPoints,
        anchorNow: now,
      );
    }
    out.add(brlVals[i] + mvTotal);
  }
  return ValuationChartSeries(
    valuationMillions: out,
    sampleTimes: List<DateTime>.from(times),
  );
}

/// Uma linha da lista “Minhas Movimentações”.
class _MovimentacaoMock {
  const _MovimentacaoMock({
    required this.entrada,
    required this.tipoLinha1,
    required this.detalheCaps,
    required this.data,
    required this.valor,
  });

  /// `true` = entrada (verde +), `false` = saída (vermelho -).
  final bool entrada;

  /// Primeira linha em negrito (ex.: Entrada / Saída).
  final String tipoLinha1;

  /// Segunda linha em caps cinza (ex.: SALDO).
  final String detalheCaps;

  /// Terceira linha: data curta.
  final String data;

  /// Valor absoluto em reais; o sinal é derivado de [entrada].
  final double valor;
}

String _carteiraFmtDataPortugues(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

/// Curva fictícia do convidado: evolução do custo até ao valor de mercado atual.
List<double> _carteiraGuestSparkline(double custoBrl, double valorAtualMercadoBrl) {
  if (!(custoBrl > 0) || !custoBrl.isFinite) {
    return List<double>.filled(7, valorAtualMercadoBrl);
  }
  return List<double>.generate(7, (i) {
    final t = i / 6.0;
    return custoBrl + (valorAtualMercadoBrl - custoBrl) * t;
  });
}

_MovimentacaoMock _ledgerFirestoreParaLinha(Map<String, dynamic> m) {
  final entrada = (m['dir'] as String?) == 'in';
  final tipoLinha1 = entrada ? 'Entrada' : 'Saída';
  final raw = (m['headline'] as String?)?.trim();
  final detalheCaps =
      (raw != null && raw.isNotEmpty) ? raw.toUpperCase() : 'MOVIMENTAÇÃO';
  final ts = m['createdAt'];
  final quando = ts is Timestamp ? ts.toDate() : DateTime.now();
  return _MovimentacaoMock(
    entrada: entrada,
    tipoLinha1: tipoLinha1,
    detalheCaps: detalheCaps,
    data: _carteiraFmtDataPortugues(quando),
    valor: (m['amountBrl'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Soma do valor de mercado das posições (tokens × cotação do catálogo). Sem cotação
/// válida, usa o custo da posição (mesmo critério que “Valor atual” nos cartões).
double _carteiraSomaValorMercadoPosicoes(
  QuerySnapshot<Map<String, dynamic>> snap,
  Map<String, CatalogStartup> byFirestoreId,
) {
  var sum = 0.0;
  for (final doc in snap.docs) {
    final match = _catalogMatchParaPosicaoDoc(doc, byFirestoreId);
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

/// Resolve o `CatalogStartup` cuja [CatalogStartup.firestoreId] coincide com a posição.
///
/// O ID da posição é o **document id** (`simulateWallet` grava em `positions.doc(startupId)`).
CatalogStartup? _catalogMatchParaPosicaoDoc(
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

// --- Tela pública --------------------------------------------------------------

/// Ecrã **Carteira** com scroll vertical: resumo, gráfico, startups e extrato.
///
/// O estado local gere o **período do gráfico** ([ValuationPeriod]) e se os
/// valores sensíveis estão **ocultos** (ícone de olho ao lado do título).
class CarteiraScreen extends StatefulWidget {
  const CarteiraScreen({
    super.key,
    this.wrapWithSafeArea = true,
    this.onCompraVendaTokens,
    /// Incrementado pelo [DashboardScreen] ao pedir scroll até «Minhas Startups Investidas».
    this.scrollStartupsSectionTick,
    /// Quando `false`, o ecrã assume **convidado** sem ler [FirebaseAuth] —
    /// útil em [flutter test] no VM (sem canais nativos do Firebase).
    this.usarFirebaseParaSessao = true,
  });

  /// Quando `false`, o antecessor (ex.: [MesclaMainShell]) já aplicou
  /// [SafeArea] — evita recortar duas vezes a mesma margem.
  final bool wrapWithSafeArea;

  /// Quando preenchido (ex.: a partir de [DashboardScreen]), o botão “Compra / Venda
  /// de Tokens” no card de saldo deixa o “em breve” e abre o separador Balcão.
  final VoidCallback? onCompraVendaTokens;

  /// Pulso externo (ex.: botão «Ver todas» no Início) para descer até à lista investida.
  final ValueNotifier<int>? scrollStartupsSectionTick;

  /// Se `false`, não acede a [FirebaseAuth] (testes de widget no desktop).
  final bool usarFirebaseParaSessao;

  @override
  State<CarteiraScreen> createState() => _CarteiraScreenState();
}

class _CarteiraScreenState extends State<CarteiraScreen> {
  /// Id do utilizador ou `null` (convidado). Respeita [CarteiraScreen.usarFirebaseParaSessao].
  String? get _uidSessao =>
      widget.usarFirebaseParaSessao
          ? FirebaseAuth.instance.currentUser?.uid
          : null;

  /// Período inicial alinhado ao gráfico de valuation do detalhe ([ValuationPeriod.mensal]).
  ValuationPeriod _periodo = ValuationPeriod.mensal;

  /// Quando `true`, valores em reais, percentagens e o gráfico são mascarados
  /// (privacidade em demo, igual à ideia do dashboard com o ícone de olho).
  bool _hideValues = false;

  /// Ancora a secção “Minhas Startups Investidas” para o botão do card roxo a
  /// fazer scroll até aqui com [Scrollable.ensureVisible].
  final GlobalKey _startupsSecaoKey = GlobalKey();

  /// Chaves PIX em **memória** só para convidado / testes sem `users/{uid}`.
  final List<PixChaveUi> _chavesPixConvidado = [];

  /// Lista de movimentações expandida (`true`) ou só as 3 mais recentes (`false`).
  bool _movimentacoesVerTodas = false;

  /// Mesma lógica para “Minhas Startups Investidas”: até 3 cards; “Ver todas” expande.
  bool _startupsInvestidasVerTodas = false;

  /// Callable `listStartups` — alinhado ao Explorar/Balcão para logos e metadados.
  late final StartupCatalogFunctionsService _catalogFunctionsService;

  /// Mini-gráficos das startups investidas: [getStartupMarketStats] por doc id (~2 min).
  Future<Map<String, BalcaoStartupMarketStats?>>? _investidasMarketStatsFuture;
  String _investidasMarketStatsCacheKey = '';

  static const _horizontalPadding = 20.0;
  static const _sectionGap = 24.0;

  /// Saldo BRL fictício (convidado). O total do hero = isto + valor de mercado das startups mock.
  static const _saldoBrlDisponivelConvidado = 2300.0;

  static double _patrimonioTotalConvidado() =>
      _saldoBrlDisponivelConvidado +
      _startups.fold<double>(0, (a, s) => a + s.valorMercadoAtualBrl);

  /// Lista fixa de movimentações (convidado): ordem **mais recente primeiro**,
  /// alinhada ao extrato Firestore (`orderBy` descendente).
  static const List<_MovimentacaoMock> _movimentacoes = [
    _MovimentacaoMock(
      entrada: true,
      tipoLinha1: 'Entrada',
      detalheCaps: 'CRÉDITO PIX',
      data: '02/05/2026',
      valor: 1_000_000,
    ),
    _MovimentacaoMock(
      entrada: true,
      tipoLinha1: 'Entrada',
      detalheCaps: 'SALDO',
      data: '15/04/2026',
      valor: 10000,
    ),
    _MovimentacaoMock(
      entrada: false,
      tipoLinha1: 'Saída',
      detalheCaps: 'COMPRA TOKEN CBM',
      data: '14/04/2026',
      valor: 1500,
    ),
    _MovimentacaoMock(
      entrada: true,
      tipoLinha1: 'Entrada',
      detalheCaps: 'DIVIDENDOS',
      data: '10/04/2026',
      valor: 320.5,
    ),
    _MovimentacaoMock(
      entrada: false,
      tipoLinha1: 'Saída',
      detalheCaps: 'TAXA DE PLATAFORMA',
      data: '01/04/2026',
      valor: 12.9,
    ),
  ];

  /// Startups mock (nomes iguais ao dashboard/catálogo de referência).
  static const List<CarteiraInvestedPositionModel> _startups = [
    CarteiraInvestedPositionModel(
      nome: 'GreenFlow',
      categoria: 'AGROTECH',
      rendimentoLabel: '+18.5%',
      totalInvestido: 4200,
      valorMercadoAtualBrl: 4977,
      corLogo: Color(0xFF22C55E),
      icone: Icons.eco_outlined,
    ),
    CarteiraInvestedPositionModel(
      nome: 'CyberMesh',
      categoria: 'CYBERSECURITY',
      rendimentoLabel: '+12.3%',
      totalInvestido: 3150,
      valorMercadoAtualBrl: 3537,
      corLogo: Color(0xFF18181B),
      icone: Icons.security_outlined,
    ),
    CarteiraInvestedPositionModel(
      nome: 'Healthly',
      categoria: 'HEALTHTECH',
      rendimentoLabel: '+9.8%',
      totalInvestido: 2800,
      valorMercadoAtualBrl: 3074,
      corLogo: Color(0xFF14B8A6),
      icone: Icons.favorite_outline,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Cliente HTTP das Cloud Functions; partilha o mesmo contrato que [CatalogScreen]/[BalcaoTabScreen].
    _catalogFunctionsService = StartupCatalogFunctionsService();
    widget.scrollStartupsSectionTick?.addListener(
      _onPedidoScrollExternoParaStartups,
    );
  }

  @override
  void didUpdateWidget(CarteiraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollStartupsSectionTick !=
        widget.scrollStartupsSectionTick) {
      oldWidget.scrollStartupsSectionTick?.removeListener(
        _onPedidoScrollExternoParaStartups,
      );
      widget.scrollStartupsSectionTick?.addListener(
        _onPedidoScrollExternoParaStartups,
      );
    }
  }

  @override
  void dispose() {
    widget.scrollStartupsSectionTick?.removeListener(
      _onPedidoScrollExternoParaStartups,
    );
    super.dispose();
  }

  void _onPedidoScrollExternoParaStartups() {
    _scrollParaStartupsInvestidas();
  }

  /// Mensagem rápida: ações ainda sem backend nesta branch.
  void _emBreve(String acao) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$acao — em breve.')),
    );
  }

  /// Abre o fluxo **Adicionar fundos** (valor → confirmação → PIX).
  void _abrirAdicionarFundos() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const AdicionarFundosScreen(),
      ),
    );
  }

  // --- Secção “Minhas Chaves PIX” (Firestore ou memória) -----------------------

  /// Formulário no [AlertDialog]; persiste via [persistLista] (Firestore ou RAM).
  Future<void> _dialogCadastrarOuEditarChave({
    required List<PixChaveUi> atual,
    PixChaveUi? existente,
    required Future<void> Function(List<PixChaveUi> next) persistLista,
  }) async {
    var tipo = existente?.tipoLabel ?? 'E-mail';
    final valorCtrl = TextEditingController(
      text: existente == null
          ? ''
          : textoInicialCampoChavePix(tipo, existente.valor),
    );
    final apelidoCtrl = TextEditingController(text: existente?.apelido ?? '');
    const tipos = ['E-mail', 'CPF', 'Telefone', 'Chave aleatória'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(
                existente == null ? 'Cadastrar chave PIX' : 'Editar chave PIX',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(tipo),
                      initialValue: tipo,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: [
                        for (final t in tipos)
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() {
                          tipo = v;
                          valorCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    PixChaveValorTextField(
                      key: ValueKey<String>('valor_$tipo'),
                      tipoLabel: tipo,
                      controller: valorCtrl,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apelidoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Apelido (opcional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final err = mensagemErroValidacaoPixChave(
                      tipo,
                      valorCtrl.text,
                    );
                    if (err != null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(err)),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) {
      valorCtrl.dispose();
      apelidoCtrl.dispose();
      return;
    }

    final v = pixValorParaPersistencia(tipo, valorCtrl.text);
    valorCtrl.dispose();
    final ap = apelidoCtrl.text.trim();
    apelidoCtrl.dispose();
    if (v.isEmpty) return;

    final next = List<PixChaveUi>.from(atual);
    if (existente == null) {
      next.add(
        PixChaveUi(
          id: 'pix_${DateTime.now().millisecondsSinceEpoch}',
          tipoLabel: tipo,
          valor: v,
          apelido: ap.isEmpty ? null : ap,
        ),
      );
    } else {
      final i = next.indexWhere((e) => e.id == existente.id);
      if (i >= 0) {
        next[i] = PixChaveUi(
          id: existente.id,
          tipoLabel: tipo,
          valor: v,
          apelido: ap.isEmpty ? null : ap,
        );
      }
    }

    try {
      await persistLista(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível guardar as chaves: $e')),
      );
    }
  }

  Future<void> _confirmarExcluirChave(
    PixChaveUi c,
    List<PixChaveUi> atual,
    Future<void> Function(List<PixChaveUi> next) persistLista,
  ) async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir chave?'),
        content: Text('Remover "${c.rotuloLista}" da lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (sim != true || !mounted) return;
    final next = List<PixChaveUi>.from(atual)..removeWhere((e) => e.id == c.id);
    try {
      await persistLista(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir: $e')),
      );
    }
  }

  /// Cartão branco com lista de chaves e ações, abaixo do gráfico de saldo.
  Widget _blocoMinhasChavesPix({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required List<PixChaveUi> chavesPix,
    required Future<void> Function(List<PixChaveUi> next) persistLista,
  }) {
    final onSurface = colorScheme.onSurface;
    final card = AppColors.themeCardSurface(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Minhas Chaves PIX',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: card,
          borderRadius: BorderRadius.circular(22),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (chavesPix.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhuma chave cadastrada. Adicione uma para usar no saque.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                        height: 1.35,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < chavesPix.length; i++) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        chavesPix[i].rotuloLista,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                      subtitle: Text(
                        chavesPix[i].valorParaListagem,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                            onPressed: () => _dialogCadastrarOuEditarChave(
                              atual: chavesPix,
                              existente: chavesPix[i],
                              persistLista: persistLista,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Excluir',
                            onPressed: () => _confirmarExcluirChave(
                              chavesPix[i],
                              chavesPix,
                              persistLista,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < chavesPix.length - 1)
                      Divider(height: 1, color: AppColors.cardDivider(theme)),
                  ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _dialogCadastrarOuEditarChave(
                      atual: chavesPix,
                      persistLista: persistLista,
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Cadastrar chave'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Convidado: lista em RAM. Logado: [Stream] de `users/{uid}.chavesPix`.
  Widget _secaoMinhasChavesPix({
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    if (_uidSessao == null) {
      return _blocoMinhasChavesPix(
        theme: theme,
        colorScheme: colorScheme,
        chavesPix: _chavesPixConvidado,
        persistLista: (next) async {
          if (!mounted) return;
          setState(() {
            _chavesPixConvidado
              ..clear()
              ..addAll(next);
          });
        },
      );
    }

    return StreamBuilder<List<PixChaveUi>>(
      stream: UserFirestoreService.watchChavesPix(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Chaves PIX não carregadas (${snap.error}).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryLabel(theme),
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snap.data ?? const <PixChaveUi>[];
        return _blocoMinhasChavesPix(
          theme: theme,
          colorScheme: colorScheme,
          chavesPix: list,
          persistLista: UserFirestoreService.saveChavesPix,
        );
      },
    );
  }

  /// Abre o fluxo **Sacar** (valor → confirmação → senha visual → comprovante).
  void _abrirSacar() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SacarValorScreen(
          chavesPixIniciais: List<PixChaveUi>.from(
            _uidSessao == null ? _chavesPixConvidado : const <PixChaveUi>[],
          ),
          onChavesAlteradas: (lista) {
            if (_uidSessao == null && mounted) {
              setState(() {
                _chavesPixConvidado
                  ..clear()
                  ..addAll(lista);
              });
            }
          },
          usarFirebaseParaSessao: widget.usarFirebaseParaSessao,
        ),
      ),
    );
  }

  /// Desce o scroll até à lista de startups (botão “Ver Startups Investidas”).
  ///
  /// [WidgetsBinding.addPostFrameCallback] garante que o [BuildContext] da
  /// chave já está ligado ao ecrã antes de pedirmos o scroll.
  void _scrollParaStartupsInvestidas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _startupsSecaoKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
    });
  }

  /// Alterna mostrar / ocultar valores (disparado pelo [IconButton] do olho).
  void _toggleOcultarValores() {
    setState(() => _hideValues = !_hideValues);
  }

  /// Gráfico de convidado: mesma forma que o mock de saldo, escala para [património total].
  ValuationChartSeries _seriePatrimonioConvidadoMock() {
    final base = carteiraSaldoSeries(_periodo);
    final meta = _patrimonioTotalConvidado();
    final last = base.valuationMillions.last;
    if (last.abs() < 1e-9) return base;
    final scale = meta / last;
    return ValuationChartSeries(
      valuationMillions:
          base.valuationMillions.map((v) => v * scale).toList(),
      sampleTimes: base.sampleTimes,
    );
  }

  /// Gráfico: mock património (convidado) ou evolução do património total (logado).
  Widget _evolucaoSaldoBlock({
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final uid = _uidSessao;
    const tituloGrafico = 'Evolução do Saldo Total Investido';

    if (_hideValues) {
      return Material(
        color: AppColors.themeCardSurface(theme),
        borderRadius: BorderRadius.circular(22),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tituloGrafico,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final ValuationPeriod o in ValuationPeriod.values) ...[
                      MesclaPeriodPillChip(
                        label: o.chipLabel,
                        selected: _periodo == o,
                        primary: colorScheme.primary,
                        onTap: () => setState(() => _periodo = o),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        color: AppColors.secondaryLabel(theme),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• • • • • •',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (uid == null) {
      return ValuationEvolutionChartCard(
        selected: _periodo,
        onSelect: (ValuationPeriod p) => setState(() => _periodo = p),
        series: _seriePatrimonioConvidadoMock(),
        primary: colorScheme.primary,
        title: tituloGrafico,
        footnote: '',
        formatYAxis: formatBrl,
        formatTooltip: formatBrl,
        touchListenerKey: const ValueKey<String>('carteira_saldo_chart_touch'),
      );
    }

    // Sessão autenticada: **património total** (saldo BRL + valor de mercado das posições).
    return StreamBuilder<double>(
      stream: SimulatedWalletService.watchBrlBalance(uid),
      builder: (context, balSnap) {
        if (balSnap.connectionState == ConnectionState.waiting &&
            !balSnap.hasData &&
            balSnap.error == null) {
          return SizedBox(
            height: 280,
            child: Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            ),
          );
        }
        final saldoErro = balSnap.hasError;
        final brlNow = saldoErro ? 0.0 : (balSnap.data ?? 0.0);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: SimulatedWalletService.watchLedgerRecentForChart(
            uid,
            limit: 2000,
          ),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Gráfico indisponível (${snap.error}).',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
              );
            }
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return SizedBox(
                height: 280,
                child: Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
              );
            }

            final ledgerDocs = snap.data?.docs ?? const [];
            final trades = snap.hasData && snap.data != null
                ? carteiraParseLedgerTradesAscending(snap.data!)
                : const <CarteiraLedgerTradeRow>[];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: SimulatedWalletService.watchPositions(uid),
              builder: (context, posSnap) {
                if (posSnap.connectionState == ConnectionState.waiting &&
                    !posSnap.hasData &&
                    posSnap.error == null) {
                  return SizedBox(
                    height: 280,
                    child: Center(
                      child:
                          CircularProgressIndicator(color: colorScheme.primary),
                    ),
                  );
                }
                final posDocs = posSnap.data?.docs ?? const [];

                return FutureBuilder<List<CatalogStartup>>(
                  future: StartupCatalogListCache.instance
                      .fullList(_catalogFunctionsService),
                  builder: (context, catalogSnap) {
                    if (catalogSnap.connectionState == ConnectionState.waiting &&
                        !catalogSnap.hasData &&
                        catalogSnap.error == null) {
                      return SizedBox(
                        height: 280,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                        ),
                      );
                    }
                    final catalog = catalogSnap.hasError
                        ? const <CatalogStartup>[]
                        : (catalogSnap.data ?? const <CatalogStartup>[]);
                    final byFirestoreId = <String, CatalogStartup>{};
                    for (final s in catalog) {
                      final id = s.firestoreId?.trim();
                      if (id != null && id.isNotEmpty) {
                        byFirestoreId[id] = s;
                      }
                    }

                    return FutureBuilder<Map<String, BalcaoStartupMarketStats?>>(
                      future: _marketStatsForInvestidasDocs(posDocs),
                      builder: (context, mktSnap) {
                        final statsMap = mktSnap.data ??
                            const <String, BalcaoStartupMarketStats?>{};
                        final now = DateTime.now();
                        final brlSerie = saldoBrlEvolucaoSeries(
                          docsNewestFirst: ledgerDocs,
                          periodo: _periodo,
                          now: now,
                          brlNow: brlNow,
                        );
                        final seriePatrimonio =
                            carteiraPatrimonioEvolucaoSeries(
                          serieSaldoBrl: brlSerie,
                          tradesAsc: trades,
                          positionDocs: posDocs,
                          catalogByFirestoreId: byFirestoreId,
                          marketStatsByStartupId: statsMap,
                          now: now,
                        );

                        return ValuationEvolutionChartCard(
                          selected: _periodo,
                          onSelect: (ValuationPeriod p) =>
                              setState(() => _periodo = p),
                          series: seriePatrimonio,
                          primary: colorScheme.primary,
                          title: tituloGrafico,
                          footnote: '',
                          formatYAxis: formatBrl,
                          formatTooltip: formatBrl,
                          touchListenerKey: const ValueKey<String>(
                            'carteira_saldo_chart_touch',
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Secção após o gráfico: saldo **em reais** (BRL), distinto do valor em tokens.
  Widget _secaoSaldoEmReais({
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final uid = _uidSessao;
    final onSurface = colorScheme.onSurface;
    final card = AppColors.themeCardSurface(theme);
    final secondary = AppColors.secondaryLabel(theme);

    final tituloSecao = Text(
      'Saldo em reais',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: onSurface,
      ),
    );

    const tooltipSaldoReais =
        'Valor em reais que você pode movimentar via PIX (incluindo saque). '
        'Investimentos em tokens aparecem em “Minhas Startups Investidas”.';

    Widget cardCorpo({
      required String valorLinha,
      String? mensagemErro,
    }) {
      final roxoValor = colorScheme.primary;
      return Material(
        color: card,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const BrazilFlagIcon(diameter: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Disponível na carteira',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (mensagemErro == null)
                          Tooltip(
                            message: tooltipSaldoReais,
                            showDuration: const Duration(seconds: 6),
                            triggerMode: TooltipTriggerMode.tap,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mensagemErro ?? valorLinha,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            mensagemErro != null ? colorScheme.error : roxoValor,
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

    if (uid == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tituloSecao,
          const SizedBox(height: 12),
          cardCorpo(valorLinha: _brlParaExibicao(_patrimonioTotalConvidado())),
        ],
      );
    }

    return StreamBuilder<double>(
      stream: SimulatedWalletService.watchBrlBalance(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tituloSecao,
              const SizedBox(height: 12),
              cardCorpo(
                valorLinha: '',
                mensagemErro: 'Não foi possível carregar o saldo em reais.',
              ),
            ],
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tituloSecao,
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
              ),
            ],
          );
        }
        final brl = snap.data ?? 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tituloSecao,
            const SizedBox(height: 12),
            cardCorpo(valorLinha: _brlParaExibicao(brl)),
          ],
        );
      },
    );
  }

  /// Valor em reais para a UI: mascarado ou formatado com [formatBrl].
  String _brlParaExibicao(double value) {
    if (_hideValues) return 'R\$ ••••••';
    return formatBrl(value);
  }

  /// Valor de mercado (tokens × cotação): mascarado, `—` se indisponível.
  String _mercadoBrlParaExibicao(double? value) {
    if (_hideValues) return 'R\$ ••••••';
    if (value == null || !value.isFinite) return '—';
    return formatBrl(value);
  }

  /// Percentagem ou texto de tendência: mascarado ou o texto original.
  String _percentParaExibicao(String value) {
    if (_hideValues) return '•••';
    return value;
  }

  /// Texto completo do chip “+ X% este mês” quando visível (convidado sem sessão).
  String get _trendTextCompleto => '+ 14.2% este mês';

  Widget _blocoSaldoHero() {
    final uid = _uidSessao;
    if (uid == null) {
      return _SaldoHeroCard(
        totalLabel: 'SALDO TOTAL INVESTIDO',
        totalValue: _brlParaExibicao(_patrimonioTotalConvidado()),
        trendText: _hideValues ? '• • • • • •' : _trendTextCompleto,
        onAdicionar: _abrirAdicionarFundos,
        onVerStartups: _scrollParaStartupsInvestidas,
        onSacar: _abrirSacar,
        onVenderTokens: widget.onCompraVendaTokens ??
            () => _emBreve('Compra / Venda de tokens'),
      );
    }

    return StreamBuilder<double>(
      stream: SimulatedWalletService.watchBrlBalance(uid),
      builder: (context, balSnap) {
        if (balSnap.connectionState == ConnectionState.waiting &&
            !balSnap.hasData &&
            balSnap.error == null) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final saldoErro = balSnap.hasError;
        final brl = (!balSnap.hasData || saldoErro)
            ? 0.0
            : (balSnap.data ?? 0.0);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: SimulatedWalletService.watchPositions(uid),
          builder: (context, posSnap) {
            if (posSnap.connectionState == ConnectionState.waiting &&
                !posSnap.hasData &&
                posSnap.error == null) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final posErro = posSnap.hasError;
            return FutureBuilder<List<CatalogStartup>>(
              future:
                  StartupCatalogListCache.instance.fullList(_catalogFunctionsService),
              builder: (context, catalogSnap) {
                if (catalogSnap.connectionState == ConnectionState.waiting &&
                    !catalogSnap.hasData &&
                    catalogSnap.error == null) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final catalog = catalogSnap.hasError
                    ? const <CatalogStartup>[]
                    : (catalogSnap.data ?? const <CatalogStartup>[]);
                final byFirestoreId = <String, CatalogStartup>{};
                for (final s in catalog) {
                  final id = s.firestoreId?.trim();
                  if (id != null && id.isNotEmpty) {
                    byFirestoreId[id] = s;
                  }
                }

                var valorMercadoPosicoes = 0.0;
                if (!posErro &&
                    posSnap.hasData &&
                    posSnap.data != null) {
                  valorMercadoPosicoes = _carteiraSomaValorMercadoPosicoes(
                    posSnap.data!,
                    byFirestoreId,
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: SimulatedWalletService.watchLedgerRecentForChart(uid),
                  builder: (context, ledSnap) {
                    if (ledSnap.connectionState == ConnectionState.waiting &&
                        !ledSnap.hasData &&
                        ledSnap.error == null) {
                      return const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final ledErro = ledSnap.hasError;
                    final docs = ledSnap.data?.docs ?? const [];
                    final patrimonio = carteiraPatrimonioTotal(
                      brlDisponivel: brl,
                      valorMercadoPosicoes: valorMercadoPosicoes,
                    );
                    final trendText = _hideValues
                        ? '• • • • • •'
                        : (saldoErro || ledErro || posErro
                            ? 'N/D este mês'
                            : carteiraVariacaoSaldoMesLabel(
                                brlNow: brl,
                                docsNewestFirst: docs,
                                now: DateTime.now(),
                              ));

                    return _SaldoHeroCard(
                      totalLabel: 'SALDO TOTAL INVESTIDO',
                      totalValue: (saldoErro || posErro)
                          ? '—'
                          : _brlParaExibicao(patrimonio),
                      trendText: trendText,
                      onAdicionar: _abrirAdicionarFundos,
                      onVerStartups: _scrollParaStartupsInvestidas,
                      onSacar: _abrirSacar,
                      onVenderTokens: widget.onCompraVendaTokens ??
                          () => _emBreve('Compra / Venda de tokens'),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Séries `seriesDiario` por startup para o sparkline (mesma fonte que o Balcão).
  Future<Map<String, BalcaoStartupMarketStats?>>
      _marketStatsForInvestidasDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final bucket = DateTime.now().millisecondsSinceEpoch ~/ 120000;
    final ids = docs.map((d) => d.id.trim()).where((s) => s.isNotEmpty).toList()
      ..sort();
    final key = '$bucket|${ids.join('|')}';
    if (_investidasMarketStatsFuture != null &&
        _investidasMarketStatsCacheKey == key) {
      return _investidasMarketStatsFuture!;
    }
    _investidasMarketStatsCacheKey = key;
    if (ids.isEmpty) {
      _investidasMarketStatsFuture =
          Future<Map<String, BalcaoStartupMarketStats?>>.value({});
      return _investidasMarketStatsFuture!;
    }
    _investidasMarketStatsFuture =
        Future.wait(ids.map(SimulatedWalletService.fetchStartupMarketStats)).then(
      (list) {
        final m = <String, BalcaoStartupMarketStats?>{};
        for (var i = 0; i < ids.length; i++) {
          m[ids[i]] = list[i];
        }
        return m;
      },
    );
    return _investidasMarketStatsFuture!;
  }

  Widget _tituloStartupsInvestidasRow({
    required bool mostrarLinkVerTodas,
    required Color onSurface,
    required Color primary,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Minhas Startups Investidas',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
        ),
        if (mostrarLinkVerTodas)
          TextButton(
            onPressed: () => setState(
              () => _startupsInvestidasVerTodas = !_startupsInvestidasVerTodas,
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _startupsInvestidasVerTodas ? 'Ver menos' : 'Ver todas',
              style: theme.textTheme.labelLarge?.copyWith(
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// Startups investidas: Firestore `positions` + catálogo; até **3** cartões até “Ver todas”.
  Widget _blocoMinhasStartupsInvestidas({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required ValuationPeriod periodoCarteira,
  }) {
    final uid = _uidSessao;
    final primary = colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    if (uid == null) {
      final total = _startups.length;
      final mostrarLink = total > 3;
      final lista = _startupsInvestidasVerTodas || total <= 3
          ? _startups
          : _startups.take(3).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloStartupsInvestidasRow(
            mostrarLinkVerTodas: mostrarLink,
            onSurface: onSurface,
            primary: primary,
            theme: theme,
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in lista) ...[
                InvestedStartupCard(
                  startup: s.toInvestedRowUi(),
                  primary: primary,
                  hideValues: _hideValues,
                  rendimentoExibicao: _percentParaExibicao(s.rendimentoLabel),
                  investidoExibicao: _brlParaExibicao(s.totalInvestido),
                  valorAtualExibicao:
                      _mercadoBrlParaExibicao(s.valorMercadoAtualBrl),
                  sparklineValues: _carteiraGuestSparkline(
                    s.totalInvestido,
                    s.valorMercadoAtualBrl,
                  ),
                  rendimentoTone:
                      carteiraYieldToneFromFormattedLabel(s.rendimentoLabel),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SimulatedWalletService.watchPositions(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tituloStartupsInvestidasRow(
                mostrarLinkVerTodas: false,
                onSurface: onSurface,
                primary: primary,
                theme: theme,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Posições não carregadas (${snap.error}).',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tituloStartupsInvestidasRow(
                mostrarLinkVerTodas: false,
                onSurface: onSurface,
                primary: primary,
                theme: theme,
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tituloStartupsInvestidasRow(
                mostrarLinkVerTodas: false,
                onSurface: onSurface,
                primary: primary,
                theme: theme,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Sem posições registadas — credite saldo pelo PIX e '
                  'compre tokens no Balcão.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
        }

        final total = docs.length;
        final mostrarLink = total > 3;
        final visDocs = _startupsInvestidasVerTodas || total <= 3
            ? docs
            : docs.take(3).toList();

        // Mesma lista em memória que Explorar/Balcão (`listStartups` deduplicado).
        // Enquanto carrega: spinner; se falhar a callable, lista posições só com dados da wallet.
        return FutureBuilder<List<CatalogStartup>>(
          future: StartupCatalogListCache.instance.fullList(_catalogFunctionsService),
          builder: (context, catalogSnap) {
            if (catalogSnap.connectionState == ConnectionState.waiting &&
                !catalogSnap.hasData &&
                catalogSnap.error == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tituloStartupsInvestidasRow(
                    mostrarLinkVerTodas: mostrarLink,
                    onSurface: onSurface,
                    primary: primary,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }

            // `hasError` → catálogo vazio: cards continuam com fallback só pelo Firestore da posição.
            final catalog = catalogSnap.hasError
                ? const <CatalogStartup>[]
                : (catalogSnap.data ?? const <CatalogStartup>[]);
            final byFirestoreId = <String, CatalogStartup>{};
            for (final s in catalog) {
              final id = s.firestoreId?.trim();
              if (id != null && id.isNotEmpty) {
                byFirestoreId[id] = s;
              }
            }

            final agora = DateTime.now();
            final inicio = _carteiraInicioPeriodo(periodoCarteira, agora);
            final sampleTimes = _carteiraAmostrasTempoEntre(
              inicio: inicio,
              fim: agora,
              pontos: 7,
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: SimulatedWalletService.watchLedgerRecentForChart(
                uid,
                limit: 500,
              ),
              builder: (context, ledgerSnap) {
                final trades = ledgerSnap.hasData
                    ? carteiraParseLedgerTradesAscending(ledgerSnap.data!)
                    : const <CarteiraLedgerTradeRow>[];

                return FutureBuilder<Map<String, BalcaoStartupMarketStats?>>(
                  future: _marketStatsForInvestidasDocs(visDocs),
                  builder: (context, mktSnap) {
                    final statsPorStartup =
                        mktSnap.data ?? const <String, BalcaoStartupMarketStats?>{};

                    final children = <Widget>[];
                    for (final doc in visDocs) {
                      final match =
                          _catalogMatchParaPosicaoDoc(doc, byFirestoreId);
                      final startup = mapFirestorePosicaoParaInvestida(
                        doc,
                        catalogMatch: match,
                      );
                      final held =
                          (doc.data()['tokensHeld'] as num?)?.toDouble() ??
                              0.0;
                      final px = match?.tokenPrice ?? 0.0;
                      final cost =
                          (doc.data()['costBasisBrl'] as num?)?.toDouble() ??
                              0.0;
                      final rendTone = carteiraYieldTone(
                        costBasisBrl: cost,
                        tokensHeld: held,
                        tokenPriceBrl: px,
                      );
                      final mvBrl = (px > 1e-9 && held.isFinite && held >= 0)
                          ? held * px
                          : null;
                      final st = statsPorStartup[doc.id.trim()];
                      final spark = carteiraSingleStartupSparklineValues(
                        trades,
                        startupId: doc.id,
                        fallbackPriceBrl: px,
                        sampleTimes: sampleTimes,
                        tokensHeldNowFromDoc: held,
                        marketPriceSeries: st?.seriesDiarioPoints,
                        anchorNow: agora,
                      );
                      children.addAll([
                        InvestedStartupCard(
                          startup: startup.toInvestedRowUi(),
                          primary: primary,
                          hideValues: _hideValues,
                          rendimentoExibicao:
                              _percentParaExibicao(startup.rendimentoLabel),
                          investidoExibicao: _brlParaExibicao(cost),
                          valorAtualExibicao:
                              _mercadoBrlParaExibicao(mvBrl),
                          sparklineValues: spark,
                          rendimentoTone: rendTone,
                        ),
                        const SizedBox(height: 12),
                      ]);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _tituloStartupsInvestidasRow(
                          mostrarLinkVerTodas: mostrarLink,
                          onSurface: onSurface,
                          primary: primary,
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _tituloMovimentacoesRow({
    required bool mostrarLinkVerTodas,
    required Color onSurface,
    required Color primary,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Minhas Movimentações',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
        ),
        if (mostrarLinkVerTodas)
          TextButton(
            onPressed: () =>
                setState(() => _movimentacoesVerTodas = !_movimentacoesVerTodas),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _movimentacoesVerTodas ? 'Ver menos' : 'Ver todas',
              style: theme.textTheme.labelLarge?.copyWith(
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  void _abrirDetalheMovimentacao({
    required _MovimentacaoMock mov,
    Map<String, dynamic>? ledger,
  }) {
    final detalhe = ledger != null
        ? CarteiraMovimentacaoDetalhe.fromLedger(
            ledger,
            formatarBrl: _brlParaExibicao,
          )
        : CarteiraMovimentacaoDetalhe.fromConvidadoMock(
            entrada: mov.entrada,
            detalheCaps: mov.detalheCaps,
            dataDdMmYyyy: mov.data,
            valorNumerico: mov.valor,
            formatarBrl: _brlParaExibicao,
          );
    Navigator.of(context).push<void>(
      MesclaMaterialRoute.fadeSlide<void>(
        (context) => CarteiraMovimentacaoDetalheScreen(detalhe: detalhe),
      ),
    );
  }

  Widget _blocoMinhasMovimentacoes({
    required Color primary,
    required Color onSurface,
    required ThemeData theme,
  }) {
    final uid = _uidSessao;
    if (uid == null) {
      final total = _movimentacoes.length;
      final mostrarLink = total > 3;
      final lista = _movimentacoesVerTodas || total <= 3
          ? _movimentacoes
          : _movimentacoes.take(3).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloMovimentacoesRow(
            mostrarLinkVerTodas: mostrarLink,
            onSurface: onSurface,
            primary: primary,
            theme: theme,
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in lista) ...[
                _MovimentacaoCard(
                  mov: m,
                  primary: primary,
                  valorExibicao: _brlParaExibicao(m.valor),
                  onVerDetalhes: () => _abrirDetalheMovimentacao(mov: m),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SimulatedWalletService.watchLedger(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tituloMovimentacoesRow(
                mostrarLinkVerTodas: false,
                onSurface: onSurface,
                primary: primary,
                theme: theme,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Extrato indisponível (${snap.error}).',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tituloMovimentacoesRow(
                mostrarLinkVerTodas: false,
                onSurface: onSurface,
                primary: primary,
                theme: theme,
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        final docs = snap.data!.docs;
        final total = docs.length;
        final mostrarLink = total > 3;
        final visDocs = _movimentacoesVerTodas || total <= 3
            ? docs
            : docs.take(3).toList();

        if (total == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tituloMovimentacoesRow(
                mostrarLinkVerTodas: false,
                onSurface: onSurface,
                primary: primary,
                theme: theme,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Sem movimentações registadas nesta conta.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryLabel(theme),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tituloMovimentacoesRow(
              mostrarLinkVerTodas: mostrarLink,
              onSurface: onSurface,
              primary: primary,
              theme: theme,
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final doc in visDocs) ...[
                  _MovimentacaoCard(
                    mov: _ledgerFirestoreParaLinha(doc.data()),
                    primary: primary,
                    valorExibicao: _brlParaExibicao(
                      (doc.data()['amountBrl'] as num?)?.toDouble() ?? 0.0,
                    ),
                    onVerDetalhes: () => _abrirDetalheMovimentacao(
                      mov: _ledgerFirestoreParaLinha(doc.data()),
                      ledger: doc.data(),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        8,
        _horizontalPadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MesclaHeaderRow(),
          const SizedBox(height: 20),
          // Título + olho: o utilizador alterna privacidade sem sair da Carteira.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Carteira',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: _toggleOcultarValores,
                icon: Icon(
                  _hideValues
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.secondaryLabel(theme),
                ),
                tooltip: _hideValues
                    ? 'Mostrar valores'
                    : 'Ocultar valores',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _blocoSaldoHero(),
          const SizedBox(height: _sectionGap),
          _evolucaoSaldoBlock(
            theme: theme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: _sectionGap),
          _secaoSaldoEmReais(
            theme: theme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: _sectionGap),
          _secaoMinhasChavesPix(
            theme: theme,
            colorScheme: colorScheme,
          ),
          KeyedSubtree(
            key: _startupsSecaoKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: _sectionGap),
                _blocoMinhasStartupsInvestidas(
                  theme: theme,
                  colorScheme: colorScheme,
                  periodoCarteira: _periodo,
                ),
              ],
            ),
          ),
          const SizedBox(height: _sectionGap - 12),
          _blocoMinhasMovimentacoes(
            primary: colorScheme.primary,
            onSurface: onSurface,
            theme: theme,
          ),
        ],
      ),
    );

    // Filho direto do shell: não envolver de novo em SafeArea.
    if (!widget.wrapWithSafeArea) {
      return content;
    }

    return SafeArea(child: content);
  }
}

// --- Card roxo de saldo + quatro ações (grelha 2×2) ----------------------------

/// Card principal roxo com valor, badge de tendência e quatro botões brancos.
class _SaldoHeroCard extends StatelessWidget {
  const _SaldoHeroCard({
    required this.totalLabel,
    required this.totalValue,
    required this.trendText,
    required this.onAdicionar,
    required this.onVerStartups,
    required this.onSacar,
    required this.onVenderTokens,
  });

  final String totalLabel;
  final String totalValue;
  final String trendText;
  final VoidCallback onAdicionar;
  final VoidCallback onVerStartups;
  final VoidCallback onSacar;
  final VoidCallback onVenderTokens;

  /// Gradiente roxo → índigo (harmoniza com o resto do app Mescla).
  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6234EA),
      Color(0xFF4F46E5),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.seedPurple.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          const SizedBox(height: 18),
          // Quatro ações em **duas linhas** (2×2): evita botões demasiado estreitos.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PillActionButton(
                      label: '+ Adicionar Saldo',
                      onPressed: onAdicionar,
                      expandWidth: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PillActionButton(
                      label: 'Ver Startups Investidas',
                      onPressed: onVerStartups,
                      expandWidth: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PillActionButton(
                      label: 'Sacar',
                      onPressed: onSacar,
                      expandWidth: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PillActionButton(
                      label: 'Compra / Venda\nde Tokens',
                      onPressed: onVenderTokens,
                      expandWidth: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botão branco em formato de pílula (contraste com o card roxo).
///
/// [expandWidth]: quando `true`, ocupa toda a largura do pai ([Expanded]) na
/// grelha de botões do card de saldo.
class _PillActionButton extends StatelessWidget {
  const _PillActionButton({
    required this.label,
    required this.onPressed,
    this.expandWidth = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool expandWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        // Superfície clara nos botões do card roxo (lê-se bem em claro e escuro).
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: const StadiumBorder(),
        minimumSize: expandWidth ? const Size.fromHeight(44) : null,
        textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.2,
            ),
      ),
      child: expandWidth
          ? SizedBox(
              width: double.infinity,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 4,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 4,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            ),
    );

    if (!expandWidth) return button;

    return SizedBox(width: double.infinity, child: button);
  }
}

// --- Card movimentação --------------------------------------------------------

class _MovimentacaoCard extends StatelessWidget {
  const _MovimentacaoCard({
    required this.mov,
    required this.primary,
    required this.valorExibicao,
    required this.onVerDetalhes,
  });

  final _MovimentacaoMock mov;
  final Color primary;

  /// Valor em reais já formatado ou mascarado pelo ecrã pai.
  final String valorExibicao;

  final VoidCallback onVerDetalhes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sinal = mov.entrada ? '+' : '-';
    final corSimbolo = mov.entrada ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final simbolo = mov.entrada ? '+' : '−';

    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.themeMutedSurface(theme),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                simbolo,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: corSimbolo,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mov.tipoLinha1,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mov.detalheCaps,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mov.data,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$sinal $valorExibicao',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: onVerDetalhes,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(top: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Ver detalhes',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
