// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Aba **Balcão** (índice 2 do [MesclaMainShell]): listagem de startups do mesmo
// stream do catálogo, depois “mesa” com saldo mock, compra/venda, lista do dia
// e fluxo quantidade → modal → senha → detalhe (§5.3 MesclaInvest).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../carteira/format/carteira_brl.dart';
import '../../catalog/data/startup_detail_mock.dart';
import '../balcao_format.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../catalog/services/startup_catalog_service.dart';
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

/// Saldo em **tokens** na mesa (valor estável por startup para demonstração).
double balcaoSaldoTokensMock(CatalogStartup s) {
  final h = s.name.hashCode.abs() % 1000;
  return 50 + h / 10.0;
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

/// Lista de movimentações “de hoje” — valores fixos para demo.
List<BalcaoTransacaoDia> balcaoTransacoesHojeMock(CatalogStartup s) {
  return [
    BalcaoTransacaoDia(
      tipo: BalcaoOperacaoTipo.compra,
      resumo: 'Balcão de negociação',
      valorReais: s.tokenPrice * 4,
    ),
    BalcaoTransacaoDia(
      tipo: BalcaoOperacaoTipo.venda,
      resumo: 'Balcão de negociação',
      valorReais: s.tokenPrice * 1.5,
    ),
    BalcaoTransacaoDia(
      tipo: BalcaoOperacaoTipo.compra,
      resumo: 'Balcão de negociação',
      valorReais: s.tokenPrice * 2,
    ),
  ];
}

/// Tela principal do separador Balcão: primeiro escolhe startup, depois negocia.
///
/// [wrapWithSafeArea]: `false` quando o pai já é o [MesclaMainShell] com insets.
/// [startupsStreamForTesting] e [catalogService] seguem o mesmo padrão do [CatalogScreen].
class BalcaoTabScreen extends StatefulWidget {
  const BalcaoTabScreen({
    super.key,
    this.wrapWithSafeArea = true,
    this.startupsStreamForTesting,
    this.catalogService,
  });

  final bool wrapWithSafeArea;
  final Stream<List<CatalogStartup>>? startupsStreamForTesting;
  final StartupCatalogService? catalogService;

  @override
  State<BalcaoTabScreen> createState() => _BalcaoTabScreenState();
}

class _BalcaoTabScreenState extends State<BalcaoTabScreen> {
  /// Stream único no ciclo de vida — evita re-subscrever a cada [build].
  late final Stream<List<CatalogStartup>> _startupStream;

  /// Igual ao [CatalogScreen] — filtra a lista, sem barra de chips de estágio.
  final TextEditingController _searchController = TextEditingController();

  /// Se null, mostramos a **lista**; se preenchido, mostramos a **mesa** dessa startup.
  CatalogStartup? _mesaStartup;

  /// Filtro do gráfico de cotação (mesmos períodos do detalhe da startup).
  ValuationPeriod _periodoCotacao = ValuationPeriod.mensal;

  static const _horizontalPadding = 20.0;

  @override
  void initState() {
    super.initState();
    _startupStream = widget.startupsStreamForTesting ??
        (widget.catalogService ?? StartupCatalogService()).watchStartups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    });
  }

  /// Abre o ecrã onde o utilizador define a **quantidade**; o modal e a senha
  /// vêm a seguir nessa mesma cadeia de rotas.
  Future<void> _iniciarFluxoOperacao(BalcaoOperacaoTipo operacao) async {
    final startup = _mesaStartup;
    if (startup == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => BalcaoQuantidadeTokensScreen(
          startup: startup,
          operacao: operacao,
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        8,
        _horizontalPadding,
        24,
      ),
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
            StreamBuilder<List<CatalogStartup>>(
              stream: _startupStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'Não foi possível carregar as startups. Verifique a rede e o Firebase.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondaryLabel(theme),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
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
                        onTap: () => setState(() {
                          _mesaStartup = s;
                          _periodoCotacao = ValuationPeriod.mensal;
                        }),
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
            Builder(
              builder: (context) {
                final s = _mesaStartup!;
                final detail = startupDetailFor(s);
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
                final saldoTok = balcaoSaldoTokensMock(s);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MesaTokenCard(
                      pairLabel:
                          '${balcaoTickerParaStartup(s).toUpperCase()} / BRL',
                      nomeStartup: s.name,
                      categoria: s.category,
                      cotacaoFormatada: precoConhecido
                          ? formatBrl(s.tokenPrice)
                          : '—',
                      variacao24hPct: balcaoVariacao24hPercentual(p24),
                      min24h: p24.isEmpty
                          ? '—'
                          : formatBrl(
                              p24.reduce((a, b) => a < b ? a : b),
                            ),
                      max24h: p24.isEmpty
                          ? '—'
                          : formatBrl(
                              p24.reduce((a, b) => a > b ? a : b),
                            ),
                      saldoTokens: saldoTok,
                      saldoReaisTexto: balcaoBrlDisponivel(
                        saldoTok * s.tokenPrice,
                        precoConhecido,
                      ),
                      corLogo: s.logoColor,
                      icone: s.logoIcon,
                      logoPath: s.logoPath,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _iniciarFluxoOperacao(
                              BalcaoOperacaoTipo.compra,
                            ),
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
                            child: const Text('Comprar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _iniciarFluxoOperacao(
                              BalcaoOperacaoTipo.venda,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.primary,
                              backgroundColor: theme.colorScheme.surface,
                              side: BorderSide(
                                color: scheme.primary,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Vender'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ValuationEvolutionChartCard(
                      selected: _periodoCotacao,
                      onSelect: (p) => setState(() => _periodoCotacao = p),
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
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Transações de hoje',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            for (final tx in balcaoTransacoesHojeMock(_mesaStartup!)) ...[
              _TransacaoDiaTile(
                item: tx,
                primary: scheme.primary,
                theme: theme,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
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
        MesclaBrandLogo(
          boxWidth: 200,
          boxHeight: _logoHeight,
        ),
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
              Icon(Icons.chevron_right_rounded, color: primary.withValues(alpha: 0.7)),
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
    required this.saldoReaisTexto,
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
  final String saldoReaisTexto;
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
                  Container(
                    height: 1,
                    color: AppColors.cardDivider(theme),
                  ),
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
                  Container(
                    height: 1,
                    color: AppColors.cardDivider(theme),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Saldo (quantidade)',
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
                    'Saldo em reais',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryLabel(theme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    saldoReaisTexto,
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
    final tipoLabel = item.tipo == BalcaoOperacaoTipo.compra ? 'Compra' : 'Venda';
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
                    item.resumo,
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
