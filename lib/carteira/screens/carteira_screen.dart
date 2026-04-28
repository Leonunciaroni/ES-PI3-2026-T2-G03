// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela **Carteira** — protótipo visual alinhado ao Figma (saldo, evolução,
// startups investidas, movimentações). Dados fixos em memória até existir API.
//
// [wrapWithSafeArea]: quando um pai (ex.: [MesclaMainShell]) já aplicou
// [SafeArea], passa `false` para não duplicar insets no topo.

import 'package:flutter/material.dart';

import '../../catalog/data/startup_detail_mock.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mescla_header_row.dart';
import '../../widgets/mescla_period_pill_chip.dart';
import '../../widgets/valuation_evolution_chart_card.dart';
import '../format/carteira_brl.dart';
import 'adicionar_fundos_screen.dart';

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
  });

  /// Quando `false`, o antecessor (ex.: [MesclaMainShell]) já aplicou
  /// [SafeArea] — evita recortar duas vezes a mesma margem.
  final bool wrapWithSafeArea;

  /// Quando preenchido (ex.: a partir de [DashboardScreen]), o botão “Compra / Venda
  /// de Tokens” no card de saldo deixa o “em breve” e abre o separador Balcão.
  final VoidCallback? onCompraVendaTokens;

  @override
  State<CarteiraScreen> createState() => _CarteiraScreenState();
}

class _CarteiraScreenState extends State<CarteiraScreen> {
  /// Período inicial alinhado ao gráfico de valuation do detalhe ([ValuationPeriod.mensal]).
  ValuationPeriod _periodo = ValuationPeriod.mensal;

  /// Quando `true`, valores em reais, percentagens e o gráfico são mascarados
  /// (privacidade em demo, igual à ideia do dashboard com o ícone de olho).
  bool _hideValues = false;

  /// Ancora a secção “Minhas Startups Investidas” para o botão do card roxo a
  /// fazer scroll até aqui com [Scrollable.ensureVisible].
  final GlobalKey _startupsSecaoKey = GlobalKey();

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

  /// Mesmo componente de gráfico que o catálogo/detalhe da startup ([ValuationEvolutionChartCard]).
  Widget _evolucaoSaldoBlock({
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
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
                'Evolução de Saldo',
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
    return ValuationEvolutionChartCard(
      selected: _periodo,
      onSelect: (ValuationPeriod p) => setState(() => _periodo = p),
      series: carteiraSaldoSeries(_periodo),
      primary: colorScheme.primary,
      title: 'Evolução de Saldo',
      footnote: '',
      formatYAxis: formatBrl,
      formatTooltip: formatBrl,
      touchListenerKey: const ValueKey<String>('carteira_saldo_chart_touch'),
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

  /// Texto completo do chip “+ X% este mês” quando visível.
  String get _trendTextCompleto => '+ 14.2% este mês';

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
          _SaldoHeroCard(
            totalLabel: 'SALDO TOTAL INVESTIDO',
            totalValue: _brlParaExibicao(_saldoTotal),
            trendText: _hideValues ? '• • • • • •' : _trendTextCompleto,
            onAdicionar: _abrirAdicionarFundos,
            onVerStartups: _scrollParaStartupsInvestidas,
            onVenderTokens: widget.onCompraVendaTokens ??
                () => _emBreve('Compra / Venda de tokens'),
          ),
          const SizedBox(height: _sectionGap),
          _evolucaoSaldoBlock(
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
                for (final s in _startups) ...[
                  _StartupInvestidaCard(
                    startup: s,
                    primary: colorScheme.primary,
                    hideValues: _hideValues,
                    rendimentoExibicao: _percentParaExibicao(s.rendimentoLabel),
                    investidoExibicao: _brlParaExibicao(s.totalInvestido),
                  ),
                  const SizedBox(height: 12),
                ],
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
          for (final m in _movimentacoes) ...[
            _MovimentacaoCard(
              mov: m,
              primary: colorScheme.primary,
              valorExibicao: _brlParaExibicao(m.valor),
            ),
            const SizedBox(height: 10),
          ],
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

// --- Card roxo de saldo + três ações ------------------------------------------

/// Card principal roxo com valor, badge de tendência e três botões brancos.
class _SaldoHeroCard extends StatelessWidget {
  const _SaldoHeroCard({
    required this.totalLabel,
    required this.totalValue,
    required this.trendText,
    required this.onAdicionar,
    required this.onVerStartups,
    required this.onVenderTokens,
  });

  final String totalLabel;
  final String totalValue;
  final String trendText;
  final VoidCallback onAdicionar;
  final VoidCallback onVerStartups;
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
          // Os três botões na **mesma linha**; o texto pode quebrar dentro de cada
          // um ([maxLines] no [_PillActionButton]) em ecrãs estreitos.
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
              const SizedBox(width: 6),
              Expanded(
                child: _PillActionButton(
                  // Quebra explícita: em colunas estreitas “Vender Tokens” ficava
                  // numa linha só; o \n iguala a leitura aos outros botões multilinha.
                  label: 'Compra / Venda\nde Tokens',
                  onPressed: onVenderTokens,
                  expandWidth: true,
                ),
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
/// fila única de três botões do card de saldo.
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
