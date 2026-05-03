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
import '../../catalog/services/startup_firestore_mapper.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mescla_header_row.dart';
import '../../widgets/mescla_period_pill_chip.dart';
import '../../widgets/valuation_evolution_chart_card.dart';
import '../format/carteira_brl.dart';
import '../format/pix_chave_input.dart';
import '../models/pix_chave_ui.dart';
import '../services/simulated_wallet_service.dart';
import 'adicionar_fundos_screen.dart';
import 'sacar_valor_screen.dart';

// --- Série “Evolução de saldo” (R$) — alinhada ao [ValuationEvolutionChartCard] ----

List<DateTime> _carteiraSampleTimes(ValuationPeriod p) {
  switch (p) {
    case ValuationPeriod.diario:
      return _temposCarteiraDiario;
    case ValuationPeriod.semanal:
      return _temposCarteiraSemanal;
    case ValuationPeriod.mensal:
      return _temposCarteiraMensal;
    case ValuationPeriod.seisMeses:
      return _temposCarteira6m;
    case ValuationPeriod.ytd:
      return _temposCarteiraYtd;
  }
}

/// Série de saldo (valores em **reais**; campo reutiliza o mock [ValuationChartSeries]).
ValuationChartSeries carteiraSaldoSeries(ValuationPeriod p) {
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
    sampleTimes: _carteiraSampleTimes(p),
  );
}

final _temposCarteiraDiario = <DateTime>[
  DateTime(2026, 4, 13, 9, 5),
  DateTime(2026, 4, 14, 10, 30),
  DateTime(2026, 4, 15, 8, 50),
  DateTime(2026, 4, 16, 14, 20),
  DateTime(2026, 4, 17, 11, 15),
  DateTime(2026, 4, 18, 16, 40),
  DateTime(2026, 4, 19, 17, 55),
];

final _temposCarteiraSemanal = <DateTime>[
  DateTime(2026, 3, 5, 10, 0),
  DateTime(2026, 3, 12, 11, 20),
  DateTime(2026, 3, 19, 9, 45),
  DateTime(2026, 3, 26, 15, 10),
  DateTime(2026, 4, 2, 12, 30),
  DateTime(2026, 4, 9, 14, 0),
  DateTime(2026, 4, 16, 17, 25),
];

final _temposCarteiraMensal = <DateTime>[
  DateTime(2025, 10, 1, 12, 0),
  DateTime(2025, 11, 1, 12, 0),
  DateTime(2025, 12, 1, 12, 0),
  DateTime(2026, 1, 1, 12, 0),
  DateTime(2026, 2, 1, 12, 0),
  DateTime(2026, 3, 1, 12, 0),
  DateTime(2026, 4, 1, 12, 0),
];

final _temposCarteira6m = <DateTime>[
  DateTime(2025, 11, 8, 10, 0),
  DateTime(2025, 12, 10, 10, 30),
  DateTime(2026, 1, 12, 11, 0),
  DateTime(2026, 2, 9, 11, 30),
  DateTime(2026, 3, 11, 12, 0),
  DateTime(2026, 4, 5, 13, 15),
  DateTime(2026, 4, 19, 18, 0),
];

final _temposCarteiraYtd = <DateTime>[
  DateTime(2026, 1, 12, 9, 0),
  DateTime(2026, 2, 10, 9, 40),
  DateTime(2026, 3, 8, 10, 20),
  DateTime(2026, 4, 2, 11, 5),
  DateTime(2026, 4, 11, 12, 45),
  DateTime(2026, 4, 16, 14, 30),
  DateTime(2026, 4, 19, 18, 15),
];

/// Início da janela temporal de cada chip do gráfico (inclusivo).
DateTime _carteiraInicioPeriodo(ValuationPeriod p, DateTime now) {
  switch (p) {
    case ValuationPeriod.diario:
      return now.subtract(const Duration(days: 7));
    case ValuationPeriod.semanal:
      return now.subtract(const Duration(days: 49));
    case ValuationPeriod.mensal:
      return now.subtract(const Duration(days: 210));
    case ValuationPeriod.seisMeses:
      return now.subtract(const Duration(days: 183));
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

// --- Modelos simples (mock) ---------------------------------------------------

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
class _StartupMock {
  const _StartupMock({
    required this.nome,
    required this.categoria,
    required this.rendimentoLabel,
    required this.totalInvestido,
    required this.corLogo,
    required this.icone,
  });

  final String nome;
  final String categoria;
  final String rendimentoLabel;
  final double totalInvestido;
  final Color corLogo;
  final IconData icone;
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

_StartupMock _docPosicaoParaMock(
  QueryDocumentSnapshot<Map<String, dynamic>> d,
) {
  final m = d.data();
  final nome = ((m['startupName'] as String?) ?? '').trim();
  final cat = ((m['category'] as String?) ?? '—').trim();
  final setor = cat.isEmpty ? '—' : cat;
  return _StartupMock(
    nome: nome.isNotEmpty ? nome : 'Startup',
    categoria: setor.toUpperCase(),
    rendimentoLabel: 'N/D',
    totalInvestido: (m['costBasisBrl'] as num?)?.toDouble() ?? 0.0,
    corLogo: firestoreColorForSector(setor),
    icone: firestoreIconForSector(setor),
  );
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

  static const _horizontalPadding = 20.0;
  static const _sectionGap = 24.0;

  /// Saldo total mock (mesmo valor exemplo do Figma).
  static const _saldoTotal = 12450.0;

  /// Lista fixa de movimentações até existir Firestore/API.
  static const List<_MovimentacaoMock> _movimentacoes = [
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
          stream: SimulatedWalletService.watchLedgerRecentForChart(uid),
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

  Widget _listaStartupsInvestidasBloco({
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final uid = _uidSessao;
    final primary = colorScheme.primary;
    if (uid == null) {
      final filhos = <Widget>[];
      for (final s in _startups) {
        filhos.addAll([
          _StartupInvestidaCard(
            startup: s,
            primary: primary,
            hideValues: _hideValues,
            rendimentoExibicao: _percentParaExibicao(s.rendimentoLabel),
            investidoExibicao: _brlParaExibicao(s.totalInvestido),
          ),
          const SizedBox(height: 12),
        ]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: filhos,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SimulatedWalletService.watchPositions(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Posições não carregadas (${snap.error}).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryLabel(theme),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Padding(
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
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final doc in docs) ...[
              _StartupInvestidaCard(
                startup: _docPosicaoParaMock(doc),
                primary: primary,
                hideValues: _hideValues,
                rendimentoExibicao: _percentParaExibicao('N/D'),
                investidoExibicao: _brlParaExibicao(
                  (doc.data()['costBasisBrl'] as num?)?.toDouble() ?? 0.0,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _listaMovimentacoesBloco({required Color primary}) {
    final uid = _uidSessao;
    if (uid == null) {
      final filhos = <Widget>[];
      for (final m in _movimentacoes) {
        filhos.addAll([
          _MovimentacaoCard(
            mov: m,
            primary: primary,
            valorExibicao: _brlParaExibicao(m.valor),
          ),
          const SizedBox(height: 10),
        ]);
      }
      return Column(children: filhos);
    }

    final themeLocal = Theme.of(context);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SimulatedWalletService.watchLedger(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Extrato indisponível (${snap.error}).',
              style: themeLocal.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryLabel(themeLocal),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Sem movimentações registadas nesta conta.',
              textAlign: TextAlign.center,
              style: themeLocal.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryLabel(themeLocal),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final doc in docs) ...[
              _MovimentacaoCard(
                mov: _ledgerFirestoreParaLinha(doc.data()),
                primary: primary,
                valorExibicao: _brlParaExibicao(
                  (doc.data()['amountBrl'] as num?)?.toDouble() ?? 0.0,
                ),
              ),
              const SizedBox(height: 10),
            ],
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
                _SecaoTituloComLink(
                  titulo: 'Minhas Startups Investidas',
                  linkLabel: 'Ver todas',
                  onLink: () => _emBreve('Ver todas as startups'),
                  onSurface: onSurface,
                  primary: colorScheme.primary,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _listaStartupsInvestidasBloco(
                  theme: theme,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
          const SizedBox(height: _sectionGap - 12),
          _SecaoTituloComLink(
            titulo: 'Minhas Movimentações',
            linkLabel: 'Ver todas',
            onLink: () => _emBreve('Ver todas as movimentações'),
            onSurface: onSurface,
            primary: colorScheme.primary,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _listaMovimentacoesBloco(primary: colorScheme.primary),
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

// --- Secções com título + “Ver todas” ----------------------------------------

class _SecaoTituloComLink extends StatelessWidget {
  const _SecaoTituloComLink({
    required this.titulo,
    required this.linkLabel,
    required this.onLink,
    required this.onSurface,
    required this.primary,
    required this.theme,
  });

  final String titulo;
  final String linkLabel;
  final VoidCallback onLink;
  final Color onSurface;
  final Color primary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            titulo,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
        ),
        TextButton(
          onPressed: onLink,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            linkLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// --- Card startup investida ---------------------------------------------------

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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: startup.corLogo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(startup.icone, color: Colors.white, size: 26),
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
  });

  final _MovimentacaoMock mov;
  final Color primary;

  /// Valor em reais já formatado ou mascarado pelo ecrã pai.
  final String valorExibicao;

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
            Text(
              '$sinal $valorExibicao',
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
