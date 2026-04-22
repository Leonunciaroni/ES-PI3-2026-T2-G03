// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela de detalhes da startup (MesclaInvest) — layout inspirado no Figma.
// Conteúdo institucional mínimo do documento §5.2; filtros de gráfico conforme §5.4.
// Esta rota não inclui a bottom navigation bar (é um [MaterialPageRoute] empilhado).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/startup_detail_mock.dart';
import '../models/catalog_startup.dart';
import '../services/startup_detail_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/chart_scrubbing.dart';
import '../../widgets/mescla_chart_reading_card.dart';
import '../widgets/detail_demo_video_section.dart';

/// Asset do wordmark no cabeçalho (registado em `pubspec.yaml` → `flutter: assets:`).
const String _kMesclaLogoAsset = 'assets/images/mescla_logo.png';

/// Raio dos cards grandes (referência visual ~18–22 dp).
const double _kCardRadius = 22;

/// Tela completa de detalhes da startup.
///
/// Com [catalog.firestoreId] preenchido (vindo do Firestore), os dados são lidos em tempo real.
/// Sem ID ou em testes, usa [detailStreamForTesting] ou [startupDetailFor] local.
class StartupDetailScreen extends StatefulWidget {
  const StartupDetailScreen({
    super.key,
    required this.catalog,
    this.detailStreamForTesting,
  });

  /// Startup tocada no catálogo (mantém identidade visual e o ID do documento, se houver).
  final CatalogStartup catalog;

  /// Injeta um stream fixo em `flutter test` (sem Firebase).
  final Stream<StartupDetailViewData?>? detailStreamForTesting;

  @override
  State<StartupDetailScreen> createState() => _StartupDetailScreenState();
}

class _StartupDetailScreenState extends State<StartupDetailScreen> {
  /// Período ativo no gráfico "Evolução" — rótulos do PDF §5.4.
  ValuationPeriod _valuationPeriod = ValuationPeriod.mensal;

  /// Simula favoritar na lista de desejos (sem persistência).
  bool _onWishlist = false;

  /// Um único [Stream] por estado: Firestore, teste ou mock estático.
  late final Stream<StartupDetailViewData?> _detailStream;

  @override
  void initState() {
    super.initState();
    _detailStream = widget.detailStreamForTesting ??
        (widget.catalog.firestoreId != null
            ? StartupDetailService().watchDetail(widget.catalog.firestoreId!)
            : Stream<StartupDetailViewData?>.value(
                startupDetailFor(widget.catalog),
              ));
  }

  /// Iniciais para o avatar textual (ex.: "Ana Luíza Costa" → "AC").
  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts[0];
      if (s.isEmpty) return '?';
      return s[0].toUpperCase();
    }
    final first = parts.first;
    final last = parts.last;
    if (first.isEmpty || last.isEmpty) return '?';
    return ('${first[0]}${last[0]}').toUpperCase();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openDemoVideo(String? url) async {
    if (url == null || url.trim().isEmpty) {
      _snack('Vídeo não disponível neste build.');
      return;
    }
    final Uri uri = Uri.parse(url.trim());
    try {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (!ok) {
        _snack('Não foi possível abrir o link.');
      }
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      _snack(
        'Plugin de link não carregado. Pare o app, rode: flutter clean && flutter pub get && flutter run',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _snack('Erro ao abrir o vídeo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
              colors: [AppColors.gradientTop, AppColors.gradientBottom],
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<StartupDetailViewData?>(
              stream: _detailStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Não foi possível carregar os detalhes. Tente novamente.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final StartupDetailViewData _d = snapshot.data!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _DetailHeader(),
                      const SizedBox(height: 16),
                      _MainInfoCard(
                        data: _d,
                        primary: primary,
                        onWishlist: _onWishlist,
                        onToggleWishlist: () =>
                            setState(() => _onWishlist = !_onWishlist),
                        onInvest: () =>
                            _snack('Investimento simulado — em integração.'),
                      ),
                      const SizedBox(height: 14),
                      _CaptureCard(
                        headline: _d.captureHeadline,
                        progress: _d.captureProgressFraction,
                        caption: _d.captureProgressLabel,
                        primary: primary,
                      ),
                      const SizedBox(height: 14),
                      _ValuationCard(
                        roundLabel: _d.valuationRoundLabel,
                        headline: _d.valuationHeadline,
                        trend: _d.valuationTrendText,
                      ),
                      const SizedBox(height: 14),
                      _ValuationEvolutionCard(
                        selected: _valuationPeriod,
                        onSelect: (p) => setState(() => _valuationPeriod = p),
                        series: _d.chartSeriesByPeriod[_valuationPeriod]!,
                        primary: primary,
                      ),
                      const SizedBox(height: 14),
                      _PerformanceMetricsCard(metrics: _d.performanceMetrics),
                      const SizedBox(height: 14),
                      _CompanyInfoCard(data: _d, primary: primary),
                      const SizedBox(height: 14),
                      _TeamCard(
                        members: _d.teamMembers,
                        initialsFor: _initials,
                      ),
                      const SizedBox(height: 14),
                      _PdfSectionCard(
                        title: 'Sumário executivo',
                        child: Text(
                          _d.executiveSummary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PdfSectionCard(
                        title: 'Estrutura societária',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _d.societaryLines
                              .map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• $line',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PdfSectionCard(
                        title: 'Perguntas e respostas públicas',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _d.publicQa.isEmpty
                              ? [
                                  Text(
                                    'Ainda não há perguntas públicas.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ]
                              : _d.publicQa.map((qa) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'P: ${qa.question}',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'R: ${qa.answer}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                                height: 1.35,
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PdfSectionCard(
                        title: 'Vídeos demonstrativos',
                        child: DetailDemoVideoSection(
                          videoTitle: _d.demoVideoTitle,
                          videoUrl: _d.demoVideoUrl,
                          primary: primary,
                          onOpenExternal: _openDemoVideo,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Voltar + logo centrado (referência Figma).
class _DetailHeader extends StatelessWidget {
  const _DetailHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: theme.colorScheme.onSurface,
          tooltip: 'Voltar',
        ),
        Expanded(
          child: Center(
            child: Image.asset(
              _kMesclaLogoAsset,
              height: 44,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Text(
                'mescla invest',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        // Espaçador invisível para equilibrar o [IconButton] à esquerda.
        const SizedBox(width: 48),
      ],
    );
  }
}

class _MainInfoCard extends StatelessWidget {
  const _MainInfoCard({
    required this.data,
    required this.primary,
    required this.onWishlist,
    required this.onToggleWishlist,
    required this.onInvest,
  });

  final StartupDetailViewData data;
  final Color primary;
  final bool onWishlist;
  final VoidCallback onToggleWishlist;
  final VoidCallback onInvest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = data.catalog;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kCardRadius),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.logoColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(c.logoIcon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.categoryDisplay,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.longDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onInvest,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 2,
                      shadowColor: AppColors.primaryShadow(theme.colorScheme),
                    ),
                    child: const Text('Investir Agora'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onToggleWishlist,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFFF3F4F6),
                      foregroundColor: theme.colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          onWishlist
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('Lista de Desejos'),
                      ],
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

/// Card roxo de captação atual.
class _CaptureCard extends StatelessWidget {
  const _CaptureCard({
    required this.headline,
    required this.progress,
    required this.caption,
    required this.primary,
  });

  final String headline;
  final double progress;
  final String caption;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CAPTAÇÃO ATUAL',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            headline,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuationCard extends StatelessWidget {
  const _ValuationCard({
    required this.roundLabel,
    required this.headline,
    required this.trend,
  });

  final String roundLabel;
  final String headline;
  final String trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const green = Color(0xFF16A34A);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kCardRadius),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              roundLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              headline,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: green, size: 22),
                const SizedBox(width: 6),
                Text(
                  trend,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: green,
                    fontWeight: FontWeight.w700,
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

/// Gráfico de área (estilo cotação Google) + chips de período (§5.4).
class _ValuationEvolutionCard extends StatefulWidget {
  const _ValuationEvolutionCard({
    required this.selected,
    required this.onSelect,
    required this.series,
    required this.primary,
  });

  final ValuationPeriod selected;
  final ValueChanged<ValuationPeriod> onSelect;
  final ValuationChartSeries series;
  final Color primary;

  @override
  State<_ValuationEvolutionCard> createState() =>
      _ValuationEvolutionCardState();
}

class _ValuationEvolutionCardState extends State<_ValuationEvolutionCard> {
  /// Fração horizontal 0..1 enquanto o utilizador arrasta no gráfico.
  double _t = 0.5;

  /// True enquanto há contacto com o gráfico — igual ao "hover" no Google.
  bool _fingerOnChart = false;

  @override
  void didUpdateWidget(covariant _ValuationEvolutionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        !identical(oldWidget.series, widget.series)) {
      _fingerOnChart = false;
      _t = 0.5;
    }
  }

  void _atualizaComDx(double dx, double width) {
    if (width <= 0) return;
    setState(() {
      _fingerOnChart = true;
      _t = (dx / width).clamp(0.0, 1.0);
    });
  }

  void _soltaDedo() {
    if (!_fingerOnChart) return;
    setState(() => _fingerOnChart = false);
  }

  String _formatYAxis(double millions) {
    if (millions >= 1000) {
      return 'R\$ ${(millions / 1000).toStringAsFixed(1)}B';
    }
    if (millions >= 100) {
      return 'R\$ ${millions.round()}M';
    }
    return 'R\$ ${millions.toStringAsFixed(1)}M';
  }

  String _formatTooltipValue(double millions) {
    if (millions >= 1000) {
      return 'R\$ ${(millions / 1000).toStringAsFixed(2)} bi';
    }
    return 'R\$ ${millions.toStringAsFixed(2)} mi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = widget.series.valuationMillions;
    final times = widget.series.sampleTimes;
    final n = values.length;
    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    final span = (rawMax - rawMin).abs() < 1e-6 ? 1.0 : (rawMax - rawMin);
    final pad = span * 0.12 + 0.25;
    final vmin = rawMin - pad;
    final vmax = rawMax + pad;

    const plotHeight = 168.0;
    const axisWidth = 52.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kCardRadius),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Evolução de Valuation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in ValuationPeriod.values) ...[
                    _PeriodChip(
                      label: p.chipLabel,
                      selected: widget.selected == p,
                      primary: widget.primary,
                      onTap: () => widget.onSelect(p),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: plotHeight + 28,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final plotW = math.max(
                    120.0,
                    constraints.maxWidth - axisWidth,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: axisWidth,
                        height: plotHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(5, (i) {
                            final v = vmax - i * (vmax - vmin) / 4;
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _formatYAxis(v),
                                maxLines: 1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: plotHeight,
                          child: Listener(
                            key: const ValueKey<String>(
                              'startup_valuation_chart_touch',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (e) =>
                                _atualizaComDx(e.localPosition.dx, plotW),
                            onPointerMove: (e) {
                              if (!_fingerOnChart) return;
                              _atualizaComDx(e.localPosition.dx, plotW);
                            },
                            onPointerUp: (_) => _soltaDedo(),
                            onPointerCancel: (_) => _soltaDedo(),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CustomPaint(
                                  size: Size(plotW, plotHeight),
                                  painter: _ValuationAreaChartPainter(
                                    values: values,
                                    vmin: vmin,
                                    vmax: vmax,
                                    highlightT:
                                        _fingerOnChart ? _t : null,
                                    lineColor: const Color(0xFF4F6AF0),
                                    gridColor: AppColors.fieldBorder.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                ),
                                if (_fingerOnChart &&
                                    n > 0 &&
                                    times.length == n)
                                  Positioned(
                                    left: (_t * plotW - 72).clamp(
                                      0.0,
                                      math.max(0.0, plotW - 158),
                                    ),
                                    top: 4,
                                    child: MesclaChartReadingCard(
                                      dateTimeLine: formatChartSampleDateTime(
                                        dateTimeAtT(_t, times),
                                      ),
                                      valueLine: _formatTooltipValue(
                                        scalarAtT(_t, values),
                                      ),
                                      minWidth: 145,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mantenha o dedo sobre o gráfico para ver data, horário e valuation.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desenha grelha horizontal, curva suave (Catmull-Rom → cúbicas) e área sombreada.
class _ValuationAreaChartPainter extends CustomPainter {
  _ValuationAreaChartPainter({
    required this.values,
    required this.vmin,
    required this.vmax,
    required this.highlightT,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> values;
  final double vmin;
  final double vmax;

  /// Fração 0..1 no eixo X para linha vertical + ponto (mesmo critério que o tooltip).
  final double? highlightT;
  final Color lineColor;
  final Color gridColor;

  List<Offset> _points(Size size) {
    final n = values.length;
    if (n == 0) return [];
    final h = size.height;
    final w = size.width;
    double yPix(double v) {
      final t = (v - vmin) / (vmax - vmin);
      return h * (1.0 - t.clamp(0.0, 1.0));
    }

    return List.generate(n, (i) {
      final x = n == 1 ? w / 2 : (i / (n - 1)) * w;
      return Offset(x, yPix(values[i]));
    });
  }

  Path _smoothLinePath(List<Offset> pts) {
    if (pts.isEmpty) return Path();
    if (pts.length == 1) {
      return Path()..moveTo(pts[0].dx, pts[0].dy);
    }
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[0] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;

    // Grelha horizontal (5 linhas).
    for (var i = 0; i <= 4; i++) {
      final y = h * (i / 4);
      final p = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, y), Offset(w, y), p);
    }

    final pts = _points(size);
    if (pts.isEmpty) return;

    final linePath = _smoothLinePath(pts);

    // Preenchimento sob a curva (gradiente vertical).
    final fillPath = Path()..addPath(linePath, Offset.zero);
    fillPath.lineTo(pts.last.dx, h);
    fillPath.lineTo(pts.first.dx, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(Offset(w / 2, 0), Offset(w / 2, h), [
        lineColor.withValues(alpha: 0.32),
        lineColor.withValues(alpha: 0.04),
      ]);
    canvas.drawPath(fillPath, fillPaint);

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..isAntiAlias = true,
    );

    final ht = highlightT;
    if (ht != null && values.isNotEmpty) {
      final t = ht.clamp(0.0, 1.0);
      final vx = scalarAtT(t, values);
      final x = t * w;
      double yPix(double v) {
        final tp = (v - vmin) / (vmax - vmin);
        return h * (1.0 - tp.clamp(0.0, 1.0));
      }

      final y = yPix(vx);
      final guia = Paint()
        ..color = lineColor.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, h), guia);

      final fill = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, y), 7, fill);
      final borda = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(x, y), 7, borda);
    }
  }

  @override
  bool shouldRepaint(covariant _ValuationAreaChartPainter oldDelegate) {
    return !identical(oldDelegate.values, values) ||
        oldDelegate.vmin != vmin ||
        oldDelegate.vmax != vmax ||
        oldDelegate.highlightT != highlightT;
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? primary.withValues(alpha: 0.12)
          : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? primary : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PerformanceMetricsCard extends StatelessWidget {
  const _PerformanceMetricsCard({required this.metrics});

  final List<StartupPerformanceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (metrics.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kCardRadius),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Métricas de Performance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              _MetricRow(m: metrics[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.m});

  final StartupPerformanceMetric m;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: m.iconBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(m.icon, color: m.iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.labelCaps,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                m.value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card cinza claro: sede, fundação, missão.
class _CompanyInfoCard extends StatelessWidget {
  const _CompanyInfoCard({required this.data, required this.primary});

  final StartupDetailViewData data;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(_kCardRadius),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Informações da Empresa',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _InfoLine(
              icon: Icons.place_outlined,
              label: 'SEDE',
              value: data.headquarters,
              iconColor: primary,
            ),
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.calendar_today_outlined,
              label: 'FUNDADA EM',
              value: data.foundedLabel,
              iconColor: primary,
            ),
            const SizedBox(height: 12),
            Text(
              'MISSÃO',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"${data.missionQuote}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.members, required this.initialsFor});

  final List<StartupTeamMember> members;
  final String Function(String) initialsFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (members.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kCardRadius),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Membros-Chave',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: m.avatarColor,
                      child: Text(
                        initialsFor(m.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            m.role,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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

/// Secção branca genérica para blocos do documento §5.2.
class _PdfSectionCard extends StatelessWidget {
  const _PdfSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kCardRadius),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
