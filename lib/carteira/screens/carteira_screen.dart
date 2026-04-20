// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela **Carteira** — protótipo visual alinhado ao Figma (saldo, evolução,
// startups investidas, movimentações). Dados fixos em memória até existir API.
//
// [wrapWithSafeArea]: quando um pai (ex.: [MesclaMainShell]) já aplicou
// [SafeArea], passa `false` para não duplicar insets no topo.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/chart_scrubbing.dart';
import '../../widgets/mescla_chart_reading_card.dart';
import '../format/carteira_brl.dart';
import 'adicionar_fundos_screen.dart';

/// Altura normalizada (0..1) na posição horizontal **t** (0 = esquerda, 1 = direita),
/// interpolando linearmente entre os pontos mock (o mesmo critério do desenho da linha).
double _alturaNormalizadaInterpolada(double t, List<double> pontos) {
  if (pontos.isEmpty) return 0;
  if (pontos.length == 1) return pontos[0].clamp(0.0, 1.0);
  final n = pontos.length;
  final tf = (t * (n - 1)).clamp(0.0, n - 1.0);
  final i0 = tf.floor();
  final i1 = (i0 + 1).clamp(0, n - 1);
  final l = tf - i0;
  final y0 = pontos[i0].clamp(0.0, 1.0);
  final y1 = pontos[i1].clamp(0.0, 1.0);
  if (i0 == i1) return y0;
  return y0 * (1 - l) + y1 * l;
}

/// Ponto (x, y) na área do gráfico correspondente à fração [t] no eixo horizontal.
Offset _offsetGraficoEmT(double t, List<double> pontos, Size size) {
  final w = size.width;
  final h = size.height;
  final yn = _alturaNormalizadaInterpolada(t, pontos);
  final x = t.clamp(0.0, 1.0) * w;
  final y = h - yn * h;
  return Offset(x, y);
}

// --- Período do gráfico “Evolução de Saldo” ----------------------------------

/// Qual opção do seletor horizontal está ativa (cada uma muda a curva mock).
enum _PeriodoSaldo {
  diario,
  semanal,
  mensal,
  seisMeses,
  ytd,
}

extension _PeriodoSaldoLabel on _PeriodoSaldo {
  /// Texto curto mostrado no chip do seletor.
  String get label {
    switch (this) {
      case _PeriodoSaldo.diario:
        return 'Diário';
      case _PeriodoSaldo.semanal:
        return 'Semanal';
      case _PeriodoSaldo.mensal:
        return 'Mensal';
      case _PeriodoSaldo.seisMeses:
        return '6 meses';
      case _PeriodoSaldo.ytd:
        return 'YTD';
    }
  }
}

/// Valores normalizados 0..1 (altura do gráfico: 0 em baixo, 1 no topo).
///
/// O Figma mostrava eixos em “$600M”; na app usamos **escala em reais** para
/// fazer sentido com a carteira (comentário pedagógico: design vs. domínio).
List<double> _pontosParaPeriodo(_PeriodoSaldo p) {
  switch (p) {
    case _PeriodoSaldo.diario:
      return const [0.45, 0.5, 0.48, 0.55, 0.52, 0.58, 0.6];
    case _PeriodoSaldo.semanal:
      return const [0.35, 0.42, 0.4, 0.5, 0.48, 0.58, 0.65];
    case _PeriodoSaldo.mensal:
      return const [0.3, 0.38, 0.36, 0.45, 0.5, 0.55, 0.62];
    case _PeriodoSaldo.seisMeses:
      return const [0.22, 0.28, 0.32, 0.38, 0.45, 0.52, 0.68];
    case _PeriodoSaldo.ytd:
      return const [0.18, 0.25, 0.3, 0.4, 0.48, 0.58, 0.72];
  }
}

/// Teto do eixo Y em reais (só para legenda mock; a curva é normalizada).
double _valorMaxLegenda(_PeriodoSaldo p) {
  switch (p) {
    case _PeriodoSaldo.diario:
      return 15000;
    case _PeriodoSaldo.semanal:
      return 16000;
    case _PeriodoSaldo.mensal:
      return 18000;
    case _PeriodoSaldo.seisMeses:
      return 20000;
    case _PeriodoSaldo.ytd:
      return 22000;
  }
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

List<DateTime> _temposParaPeriodo(_PeriodoSaldo p) {
  switch (p) {
    case _PeriodoSaldo.diario:
      return _temposCarteiraDiario;
    case _PeriodoSaldo.semanal:
      return _temposCarteiraSemanal;
    case _PeriodoSaldo.mensal:
      return _temposCarteiraMensal;
    case _PeriodoSaldo.seisMeses:
      return _temposCarteira6m;
    case _PeriodoSaldo.ytd:
      return _temposCarteiraYtd;
  }
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

// --- Tela pública --------------------------------------------------------------

/// Ecrã **Carteira** com scroll vertical: resumo, gráfico, startups e extrato.
///
/// O estado local gere o **período do gráfico** ([_PeriodoSaldo]) e se os
/// valores sensíveis estão **ocultos** (ícone de olho ao lado do título).
class CarteiraScreen extends StatefulWidget {
  const CarteiraScreen({super.key, this.wrapWithSafeArea = true});

  /// Quando `false`, o antecessor (ex.: [MesclaMainShell]) já aplicou
  /// [SafeArea] — evita recortar duas vezes a mesma margem.
  final bool wrapWithSafeArea;

  @override
  State<CarteiraScreen> createState() => _CarteiraScreenState();
}

class _CarteiraScreenState extends State<CarteiraScreen> {
  /// Período selecionado no seletor “Diário / Semanal / …”.
  _PeriodoSaldo _periodo = _PeriodoSaldo.semanal;

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
          const _CarteiraLogoHeader(),
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
                  color: AppColors.textSecondary,
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
            onVenderTokens: () => _emBreve('Vender tokens'),
          ),
          const SizedBox(height: _sectionGap),
          _EvolucaoSaldoCard(
            periodo: _periodo,
            onPeriodoChanged: (p) => setState(() => _periodo = p),
            pontos: _pontosParaPeriodo(_periodo),
            sampleTimes: _temposParaPeriodo(_periodo),
            valorMaxLegenda: _valorMaxLegenda(_periodo),
            lineColor: colorScheme.primary,
            hideValues: _hideValues,
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

// --- Cabeçalho com logo -------------------------------------------------------

/// Faixa superior só com o logo (sem sino — Figma da Carteira).
class _CarteiraLogoHeader extends StatelessWidget {
  const _CarteiraLogoHeader();

  static const _logoHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Image.asset(
          AppColors.mesclaLogoAsset,
          height: _logoHeight,
          fit: BoxFit.contain,
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
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: const StadiumBorder(),
        minimumSize: expandWidth ? const Size.fromHeight(44) : null,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
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

// --- Evolução de saldo + gráfico ----------------------------------------------

/// Cartão branco com seletor de período e área do gráfico.
class _EvolucaoSaldoCard extends StatelessWidget {
  const _EvolucaoSaldoCard({
    required this.periodo,
    required this.onPeriodoChanged,
    required this.pontos,
    required this.sampleTimes,
    required this.valorMaxLegenda,
    required this.lineColor,
    required this.hideValues,
  });

  final _PeriodoSaldo periodo;
  final ValueChanged<_PeriodoSaldo> onPeriodoChanged;
  final List<double> pontos;
  final List<DateTime> sampleTimes;
  final double valorMaxLegenda;
  final Color lineColor;

  /// Se `true`, esconde eixo Y e curva (só forma do cartão + seletor).
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
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
              ),
            ),
            const SizedBox(height: 14),
            _PeriodoSelectorBar(
              periodo: periodo,
              onChanged: onPeriodoChanged,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _YAxisLabels(
                    maxReais: valorMaxLegenda,
                    hideValues: hideValues,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: hideValues
                        ? CustomPaint(
                            painter: _SaldoEvolutionPainter(
                              pointsNormalized: pontos,
                              lineColor: lineColor,
                              hideValues: true,
                              highlightT: null,
                            ),
                            child: const SizedBox.expand(),
                          )
                        : _SaldoChartComToque(
                            pontos: pontos,
                            sampleTimes: sampleTimes,
                            valorMaxLegenda: valorMaxLegenda,
                            lineColor: lineColor,
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

/// Rótulos do eixo Y em reais (4 degraus + zero).
class _YAxisLabels extends StatelessWidget {
  const _YAxisLabels({
    required this.maxReais,
    required this.hideValues,
  });

  final double maxReais;

  /// Quando o utilizador ocultou valores, não revelamos a escala do eixo.
  final bool hideValues;

  String _shortLabel(double v) {
    if (v >= 1000) {
      final k = (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1);
      return 'R\$ ${k}k';
    }
    return formatBrl(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 10,
    );
    // Do topo para a base: máximo → 0 (como um gráfico “financeiro” comum).
    final steps = <double>[
      maxReais,
      maxReais * 0.75,
      maxReais * 0.5,
      maxReais * 0.25,
      0,
    ];
    return SizedBox(
      width: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final v in steps)
            Text(
              hideValues ? '•••' : _shortLabel(v),
              style: style,
            ),
        ],
      ),
    );
  }
}

/// Barra cinza com opções; a ativa fica branca com sombra leve.
class _PeriodoSelectorBar extends StatelessWidget {
  const _PeriodoSelectorBar({
    required this.periodo,
    required this.onChanged,
  });

  final _PeriodoSaldo periodo;
  final ValueChanged<_PeriodoSaldo> onChanged;

  static const _opcoes = _PeriodoSaldo.values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final o in _opcoes) ...[
              _PeriodoChip(
                label: o.label,
                selected: periodo == o,
                onTap: () => onChanged(o),
                theme: theme,
              ),
              if (o != _opcoes.last) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodoChip extends StatelessWidget {
  const _PeriodoChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      elevation: selected ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? theme.colorScheme.primary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gráfico de evolução com **toque / arrastar**: mostra o valor em R$ num cartão
/// acima da linha (comportamento semelhante a gráficos com tooltip no detalhe).
class _SaldoChartComToque extends StatefulWidget {
  const _SaldoChartComToque({
    required this.pontos,
    required this.sampleTimes,
    required this.valorMaxLegenda,
    required this.lineColor,
  });

  final List<double> pontos;
  final List<DateTime> sampleTimes;
  final double valorMaxLegenda;
  final Color lineColor;

  @override
  State<_SaldoChartComToque> createState() => _SaldoChartComToqueState();
}

class _SaldoChartComToqueState extends State<_SaldoChartComToque> {
  /// `true` enquanto o dedo está premido em cima da área do gráfico.
  bool _dedoEmCima = false;

  /// Posição horizontal normalizada 0..1 (esquerda → direita do gráfico).
  double _t = 0.5;

  void _atualizaComDx(double dx, double largura) {
    if (largura <= 0) return;
    setState(() {
      _dedoEmCima = true;
      _t = (dx / largura).clamp(0.0, 1.0);
    });
  }

  void _soltaDedo() {
    if (!_dedoEmCima) return;
    setState(() => _dedoEmCima = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final yn = _alturaNormalizadaInterpolada(_t, widget.pontos);
        final valorReais = yn * widget.valorMaxLegenda;
        final tempos = widget.sampleTimes;
        final mesmoComprimento =
            tempos.length == widget.pontos.length && tempos.isNotEmpty;

        return Listener(
          key: const ValueKey<String>('carteira_saldo_chart_touch'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _atualizaComDx(e.localPosition.dx, w),
          onPointerMove: (e) => _atualizaComDx(e.localPosition.dx, w),
          onPointerUp: (_) => _soltaDedo(),
          onPointerCancel: (_) => _soltaDedo(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(w, h),
                painter: _SaldoEvolutionPainter(
                  pointsNormalized: widget.pontos,
                  lineColor: widget.lineColor,
                  hideValues: false,
                  highlightT: _dedoEmCima ? _t : null,
                ),
              ),
              if (_dedoEmCima && mesmoComprimento)
                Positioned(
                  left: (_t * w - 72).clamp(4.0, w - 158.0),
                  top: 2,
                  child: MesclaChartReadingCard(
                    dateTimeLine:
                        formatChartSampleDateTime(dateTimeAtT(_t, tempos)),
                    valueLine: formatBrl(valorReais),
                    minWidth: 145,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Desenha a linha suave + preenchimento com gradiente claro por baixo.
class _SaldoEvolutionPainter extends CustomPainter {
  _SaldoEvolutionPainter({
    required this.pointsNormalized,
    required this.lineColor,
    required this.hideValues,
    this.highlightT,
  });

  /// Lista de alturas normalizadas 0..1 (índice 0 = esquerda do gráfico).
  final List<double> pointsNormalized;
  final Color lineColor;

  /// Não desenha a curva nem o preenchimento quando o modo privado está ativo.
  final bool hideValues;

  /// Fração 0..1 no eixo X onde desenhar linha vertical + ponto (toque ativo).
  final double? highlightT;

  @override
  void paint(Canvas canvas, Size size) {
    if (hideValues || pointsNormalized.length < 2) return;

    final w = size.width;
    final h = size.height;
    final n = pointsNormalized.length;

    // Converte cada ponto normalizado em coordenadas (dx, dy).
    Offset pAt(int i) {
      final t = n == 1 ? 0.0 : i / (n - 1);
      final x = t * w;
      final yn = pointsNormalized[i].clamp(0.0, 1.0);
      final y = h - yn * h;
      return Offset(x, y);
    }

    // Liga os pontos com segmentos retos — fácil de ler e de depurar no PI.
    final linePath = Path()..moveTo(pAt(0).dx, pAt(0).dy);
    for (var i = 1; i < n; i++) {
      final o = pAt(i);
      linePath.lineTo(o.dx, o.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Indicador de leitura (arrastar o dedo): linha vertical + círculo no ponto.
    final ht = highlightT;
    if (ht != null) {
      final t = ht.clamp(0.0, 1.0);
      final alvo = _offsetGraficoEmT(t, pointsNormalized, size);
      final guia = Paint()
        ..color = lineColor.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(alvo.dx, 0), Offset(alvo.dx, h), guia);

      final fill = Paint()..color = Colors.white;
      canvas.drawCircle(alvo, 7, fill);
      final borda = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(alvo, 7, borda);
    }
  }

  @override
  bool shouldRepaint(covariant _SaldoEvolutionPainter oldDelegate) {
    return oldDelegate.pointsNormalized != pointsNormalized ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.hideValues != hideValues ||
        oldDelegate.highlightT != highlightT;
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
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        startup.categoria,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        investidoExibicao,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
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
      color: Colors.white,
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
                color: const Color(0xFFF3F4F6),
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
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mov.detalheCaps,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mov.data,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
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
