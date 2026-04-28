// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela de detalhes da startup (MesclaInvest) — layout inspirado no Figma.
// Conteúdo institucional mínimo do documento §5.2; filtros de gráfico conforme §5.4.
// Esta rota não inclui a bottom navigation bar (é um [MaterialPageRoute] empilhado).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/startup_detail_mock.dart';
import '../models/catalog_startup.dart';
import '../models/startup_detail_load_state.dart';
import '../services/startup_detail_service.dart';
import '../widgets/detail_demo_video_section.dart';
import '../widgets/mescla_detail_header.dart';
import '../widgets/mescla_pdf_section_card.dart';
import '../../theme/app_colors.dart';
import '../../widgets/valuation_evolution_chart_card.dart';

import 'socio_detail_screen.dart';

part 'startup_detail_screen_widgets.dart';

/// Tela completa de detalhes da startup.
///
/// Com [catalog.firestoreId] preenchido (vindo do Firestore), os dados são lidos em tempo real.
/// Sem ID ou em testes, usa [detailLoadStreamForTesting] ou [startupDetailFor] local.
class StartupDetailScreen extends StatefulWidget {
  const StartupDetailScreen({
    super.key,
    required this.catalog,
    this.detailService,
    this.detailLoadStreamForTesting,
  });

  /// Startup tocada no catálogo (mantém identidade visual e o ID do documento, se houver).
  final CatalogStartup catalog;

  /// Injecção opcional do serviço (testes / DI).
  final StartupDetailService? detailService;

  /// Injeta um stream fixo em `flutter test` (sem Firebase).
  final Stream<StartupDetailLoadState>? detailLoadStreamForTesting;

  @override
  State<StartupDetailScreen> createState() => _StartupDetailScreenState();
}

class _StartupDetailScreenState extends State<StartupDetailScreen> {
  /// Período ativo no gráfico "Evolução" — rótulos do PDF §5.4.
  ValuationPeriod _valuationPeriod = ValuationPeriod.mensal;

  /// Simula favoritar na lista de desejos (sem persistência).
  bool _onWishlist = false;

  /// Um único [Stream] por estado: Firestore, teste ou mock estático.
  late final Stream<StartupDetailLoadState> _detailStream;

  /// Dados a partir do card, antes do primeiro evento do stream.
  /// Evita tela vazia / [CircularProgressIndicator] a tapar a transição quando o
  /// [StreamBuilder] ainda não recebeu o snapshot do Firestore.
  late final StartupDetailLoadState? _streamInitialData;

  @override
  void initState() {
    super.initState();
    if (widget.detailLoadStreamForTesting != null) {
      _streamInitialData = null;
      _detailStream = widget.detailLoadStreamForTesting!;
    } else if (widget.catalog.firestoreId != null) {
      _streamInitialData =
          StartupDetailReady(startupDetailFor(widget.catalog));
      _detailStream = (widget.detailService ?? StartupDetailService())
          .watchDetail(widget.catalog.firestoreId!);
    } else {
      final ready = StartupDetailReady(startupDetailFor(widget.catalog));
      _streamInitialData = ready;
      _detailStream = Stream<StartupDetailLoadState>.value(ready);
    }
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
    final String normalized = videoUrlWithHttpsScheme(url) ?? url.trim();
    final Uri? uri = Uri.tryParse(normalized);
    if (uri == null) {
      _snack('Link do vídeo inválido.');
      return;
    }
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
      value: AppColors.shellOverlayStyle(theme.brightness),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.shellGradientColors(theme.brightness),
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<StartupDetailLoadState>(
              initialData: _streamInitialData,
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
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final StartupDetailLoadState? state = snapshot.data;
                if (state is StartupDetailNotFound) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Startup não encontrada.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                    ),
                  );
                }
                if (state is! StartupDetailReady) {
                  return const Center(child: CircularProgressIndicator());
                }
                final StartupDetailViewData detail = state.data;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MesclaDetailHeader(),
                      const SizedBox(height: 16),
                      _MainInfoCard(
                        data: detail,
                        primary: primary,
                        onWishlist: _onWishlist,
                        onToggleWishlist: () =>
                            setState(() => _onWishlist = !_onWishlist),
                        onInvest: () =>
                            _snack('Investimento simulado — em integração.'),
                      ),
                      const SizedBox(height: 14),
                      _CaptureCard(
                        headline: detail.captureHeadline,
                        progress: detail.captureProgressFraction,
                        caption: detail.captureProgressLabel,
                        primary: primary,
                      ),
                      const SizedBox(height: 14),
                      _ValuationCard(
                        roundLabel: detail.valuationRoundLabel,
                        headline: detail.valuationHeadline,
                        trend: detail.valuationTrendText,
                      ),
                      const SizedBox(height: 14),
                      ValuationEvolutionChartCard(
                        selected: _valuationPeriod,
                        onSelect: (p) => setState(() => _valuationPeriod = p),
                        series: detail.chartSeriesByPeriod[_valuationPeriod]!,
                        primary: primary,
                      ),
                      const SizedBox(height: 14),
                      _PerformanceMetricsCard(metrics: detail.performanceMetrics),
                      const SizedBox(height: 14),
                      _CompanyInfoCard(data: detail, primary: primary),
                      const SizedBox(height: 14),
                      _TeamCard(
                        members: detail.teamMembers,
                        initialsFor: _initials,
                        onMemberTap: (member) {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) => SocioDetailScreen(
                                data: socioDetailForTeamMember(member),
                                startupDisplayName: detail.catalog.name,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      MesclaPdfSectionCard(
                        title: 'Sumário executivo',
                        child: Text(
                          detail.executiveSummary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaryLabel(theme),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      MesclaPdfSectionCard(
                        title: 'Estrutura societária',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: detail.societaryLines
                              .map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• $line',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.secondaryLabel(theme),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      MesclaPdfSectionCard(
                        title: 'Perguntas e respostas públicas',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: detail.publicQa.isEmpty
                              ? [
                                  Text(
                                    'Ainda não há perguntas públicas.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.secondaryLabel(theme),
                                    ),
                                  ),
                                ]
                              : detail.publicQa.map((qa) {
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
                                                color: AppColors.secondaryLabel(
                                                  theme,
                                                ),
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
                      MesclaPdfSectionCard(
                        title: 'Vídeos demonstrativos',
                        child: RepaintBoundary(
                          child: DetailDemoVideoSection(
                            videoTitle: detail.demoVideoTitle,
                            videoUrl: detail.demoVideoUrl,
                            primary: primary,
                            onOpenExternal: _openDemoVideo,
                          ),
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
