// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela **Carteira** — protótipo visual alinhado ao Figma (saldo, evolução,
// startups investidas, movimentações). Com utilizador autenticado, saldo,
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
import '../../catalog/services/startup_firestore_mapper.dart';
import '../../catalog/widgets/startup_logo_avatar.dart';
import '../../navigation/mescla_material_route.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brazil_flag_icon.dart';
import '../../widgets/mescla_header_row.dart';
import '../../widgets/mescla_period_pill_chip.dart';
import '../../widgets/valuation_evolution_chart_card.dart';
import '../format/carteira_brl.dart';
import '../format/pix_chave_input.dart';
import '../models/carteira_movimentacao_detalhe.dart';
import '../models/pix_chave_ui.dart';
import '../services/simulated_wallet_service.dart';
import 'adicionar_fundos_screen.dart';
import 'carteira_movimentacao_detalhe_screen.dart';
import 'sacar_valor_screen.dart';

// --- Série “Evolução de saldo” (R$) — alinhada ao [ValuationEvolutionChartCard] ----
//
// Regras de produto aqui: (1) o gráfico da carteira é **saldo disponível em BRL**
// reconstruído a partir do ledger, não valorização de tokens; (2) os chips de período
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

/// Efeito de uma linha do ledger no saldo disponível (BRL).
double _carteiraDeltaBrlLedgerLinha(Map<String, dynamic> m) {
  final op = m['op'] as String?;
  final amt = (m['amountBrl'] as num?)?.toDouble() ?? 0.0;
  switch (op) {
    case 'credit_pix_simulated':
      return amt;
    case 'withdraw_pix_simulated':
      return -amt;
    case 'trade_buy':
      return -amt;
    case 'trade_sell':
      return amt;
    default:
      return 0.0;
  }
}

/// Reverte, a partir de [brlNow], todas as operações em
/// [rangeStartInclusive, rangeEndInclusive] (ledger mais recente primeiro).
double _carteiraBrlAntesDoIntervalo({
  required double brlNow,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docsNewestFirst,
  required DateTime rangeStartInclusive,
  required DateTime rangeEndInclusive,
}) {
  var b = brlNow;
  for (final d in docsNewestFirst) {
    final m = d.data();
    final ts = m['createdAt'];
    if (ts is! Timestamp) continue;
    final t = ts.toDate();
    if (t.isBefore(rangeStartInclusive) || t.isAfter(rangeEndInclusive)) {
      continue;
    }
    b -= _carteiraDeltaBrlLedgerLinha(m);
  }
  return b;
}

/// Património exibido no hero: saldo livre + custo das posições.
double _carteiraPatrimonioTotal({
  required double brlDisponivel,
  required double custoPosicoes,
}) =>
    brlDisponivel + custoPosicoes;

/// Variação % do **saldo disponível** (BRL) no mês civil corrente.
///
/// Este número é exato porque é derivado do ledger + saldo atual.
String _carteiraVariacaoSaldoMesLabel({
  required double brlNow,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docsNewestFirst,
  required DateTime now,
}) {
  final inicioMes = DateTime(now.year, now.month, 1);
  final brlIni = _carteiraBrlAntesDoIntervalo(
    brlNow: brlNow,
    docsNewestFirst: docsNewestFirst,
    rangeStartInclusive: inicioMes,
    rangeEndInclusive: now,
  );
  if (brlIni.abs() < 1.0) {
    if (brlNow.abs() >= 1.0) {
      return '+ 100,0% este mês';
    }
    return '+ 0,0% este mês';
  }
  final pct = (brlNow - brlIni) / brlIni * 100;
  final s = pct.toStringAsFixed(1).replaceAll('.', ',');
  final sign = pct >= 0 ? '+ ' : '';
  return '$sign$s% este mês';
}

/// Evolução do **saldo disponível** (BRL) no período, coerente com o ledger e [brlNow].
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
  final brlOpening = _carteiraBrlAntesDoIntervalo(
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
    b += _carteiraDeltaBrlLedgerLinha(m);
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

/// Dados de um card “Minhas Startups Investidas”.
///
/// Convidado: só cor + ícone (sem rede). Logado: [logoPath] preenchido quando o doc
/// da posição faz match no catálogo — ver [_docPosicaoParaMock].
class _StartupMock {
  const _StartupMock({
    required this.nome,
    required this.categoria,
    required this.rendimentoLabel,
    required this.totalInvestido,
    required this.corLogo,
    required this.icone,
    this.logoPath,
  });

  final String nome;
  final String categoria;
  final String rendimentoLabel;
  final double totalInvestido;
  final Color corLogo;
  final IconData icone;

  /// Mesmo critério que [CatalogStartup.logoPath]: Storage ou URL; null → só ícone.
  final String? logoPath;
}

String _carteiraFmtDataPortugues(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

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

double _somaCustosPosicoes(
  QuerySnapshot<Map<String, dynamic>> snap,
) {
  var sum = 0.0;
  for (final d in snap.docs) {
    sum += (d.data()['costBasisBrl'] as num?)?.toDouble() ?? 0.0;
  }
  return sum;
}

/// Monta o modelo de UI a partir do doc `positions/{startupId}` em `sim_wallet`.
///
/// Se [catalogMatch] existir (lista `listStartups` em [StartupCatalogListCache]),
/// reutiliza nome, categoria, cores/ícone do catálogo, `yieldPercentLabel` e [logoPath].
/// Sem match: só dados gravados na posição + [firestoreColorForSector]/[firestoreIconForSector].
_StartupMock _docPosicaoParaMock(
  QueryDocumentSnapshot<Map<String, dynamic>> d, {
  CatalogStartup? catalogMatch,
}) {
  final m = d.data();
  final nomeFs = ((m['startupName'] as String?) ?? '').trim();
  final nome = (catalogMatch?.name.trim().isNotEmpty ?? false)
      ? catalogMatch!.name.trim()
      : (nomeFs.isNotEmpty ? nomeFs : 'Startup');

  final catRaw =
      ((catalogMatch?.category ?? (m['category'] as String?)) ?? '—').trim();
  final setor = catRaw.isEmpty ? '—' : catRaw;

  return _StartupMock(
    nome: nome,
    categoria: setor.toUpperCase(),
    rendimentoLabel: catalogMatch?.yieldPercentLabel ?? 'N/D',
    totalInvestido: (m['costBasisBrl'] as num?)?.toDouble() ?? 0.0,
    corLogo: catalogMatch?.logoColor ?? firestoreColorForSector(setor),
    icone: catalogMatch?.logoIcon ?? firestoreIconForSector(setor),
    logoPath: catalogMatch?.logoPath,
  );
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

  static const _horizontalPadding = 20.0;
  static const _sectionGap = 24.0;

  /// Saldo total mock (mesmo valor exemplo do Figma).
  static const _saldoTotal = 12450.0;

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
  static const List<_StartupMock> _startups = [
    _StartupMock(
      nome: 'GreenFlow',
      categoria: 'AGROTECH',
      rendimentoLabel: '+18.5%',
      totalInvestido: 4200,
      corLogo: Color(0xFF22C55E),
      icone: Icons.eco_outlined,
    ),
    _StartupMock(
      nome: 'CyberMesh',
      categoria: 'CYBERSECURITY',
      rendimentoLabel: '+12.3%',
      totalInvestido: 3150,
      corLogo: Color(0xFF18181B),
      icone: Icons.security_outlined,
    ),
    _StartupMock(
      nome: 'Healthly',
      categoria: 'HEALTHTECH',
      rendimentoLabel: '+9.8%',
      totalInvestido: 2800,
      corLogo: Color(0xFF14B8A6),
      icone: Icons.favorite_outline,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Cliente HTTP das Cloud Functions; partilha o mesmo contrato que [CatalogScreen]/[BalcaoTabScreen].
    _catalogFunctionsService = StartupCatalogFunctionsService();
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

  /// Gráfico: mock (convidado) ou evolução do saldo em BRL a partir do extrato.
  Widget _evolucaoSaldoBlock({
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final uid = _uidSessao;
    const tituloGrafico = 'Evolução de Saldo';

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
        series: carteiraSaldoSeries(_periodo),
        primary: colorScheme.primary,
        title: tituloGrafico,
        footnote: '',
        formatYAxis: formatBrl,
        formatTooltip: formatBrl,
        touchListenerKey: const ValueKey<String>('carteira_saldo_chart_touch'),
      );
    }

    // Sessão autenticada: gráfico = **evolução do saldo BRL** (ledger + saldo atual em tempo real).
    // Não acoplar a `getWalletTokenPerformance` (valorização de tokens).
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

        // Limite alto para janelas longas (ex.: YTD) com muitas linhas no extrato.
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

            final now = DateTime.now();
            final series = saldoBrlEvolucaoSeries(
              docsNewestFirst: snap.data?.docs ?? const [],
              periodo: _periodo,
              now: now,
              brlNow: brlNow,
            );

            return ValuationEvolutionChartCard(
              selected: _periodo,
              onSelect: (ValuationPeriod p) => setState(() => _periodo = p),
              series: series,
              primary: colorScheme.primary,
              title: tituloGrafico,
              footnote: '',
              formatYAxis: formatBrl,
              formatTooltip: formatBrl,
              touchListenerKey:
                  const ValueKey<String>('carteira_saldo_chart_touch'),
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
          cardCorpo(valorLinha: _brlParaExibicao(_saldoTotal)),
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
        totalValue: _brlParaExibicao(_saldoTotal),
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
            var custo = 0.0;
            if (!posErro && posSnap.hasData && posSnap.data != null) {
              custo = _somaCustosPosicoes(posSnap.data!);
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
                final patrimonio = _carteiraPatrimonioTotal(
                  brlDisponivel: brl,
                  custoPosicoes: custo,
                );
                final trendText = _hideValues
                    ? '• • • • • •'
                    : (saldoErro || ledErro || posErro
                        ? 'N/D este mês'
                        : _carteiraVariacaoSaldoMesLabel(
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
                _StartupInvestidaCard(
                  startup: s,
                  primary: primary,
                  hideValues: _hideValues,
                  rendimentoExibicao: _percentParaExibicao(s.rendimentoLabel),
                  investidoExibicao: _brlParaExibicao(s.totalInvestido),
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

            final children = <Widget>[];
            for (final doc in visDocs) {
              final match = _catalogMatchParaPosicaoDoc(doc, byFirestoreId);
              final startup = _docPosicaoParaMock(
                doc,
                catalogMatch: match,
              );
              children.addAll([
                _StartupInvestidaCard(
                  startup: startup,
                  primary: primary,
                  hideValues: _hideValues,
                  rendimentoExibicao:
                      _percentParaExibicao(startup.rendimentoLabel),
                  investidoExibicao: _brlParaExibicao(
                    (doc.data()['costBasisBrl'] as num?)?.toDouble() ?? 0.0,
                  ),
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

// --- Card startup investida ---------------------------------------------------
// Avatar: [StartupLogoAvatar] (logo Storage/URL ou fallback cor+ícone — igual Catálogo/Balcão).

class _StartupInvestidaCard extends StatelessWidget {
  const _StartupInvestidaCard({
    required this.startup,
    required this.primary,
    required this.hideValues,
    required this.rendimentoExibicao,
    required this.investidoExibicao,
  });

  final _StartupMock startup;
  final Color primary;

  /// Controla se as mini-barras decorativas desaparecem com os valores.
  final bool hideValues;

  /// Texto já passado pelo pai (pode estar mascarado).
  final String rendimentoExibicao;
  final String investidoExibicao;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                // Mesmo widget e caches globais de URL/imagem que `catalog_startup_card` / Balcão.
                StartupLogoAvatar(
                  logoPath: startup.logoPath,
                  fallbackColor: startup.corLogo,
                  fallbackIcon: startup.icone,
                  size: 48,
                  borderRadius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        startup.nome,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        startup.categoria,
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
                      rendimentoExibicao,
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
                        investidoExibicao,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!hideValues) const _MiniBarrasRoxas(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini gráfico em barras (decorativo) — só [Row] de [Container]s.
class _MiniBarrasRoxas extends StatelessWidget {
  const _MiniBarrasRoxas();

  static final _heights = <double>[14, 22, 18, 28, 20, 32, 26];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < _heights.length; i++) ...[
          Container(
            width: 5,
            height: _heights[i],
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.35 + (i % 3) * 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (i < _heights.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
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
