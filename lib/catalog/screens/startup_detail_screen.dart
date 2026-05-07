// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela de detalhes da startup (MesclaInvest) — layout inspirado no Figma.
// Conteúdo institucional mínimo do documento §5.2; filtros de gráfico conforme §5.4.
// Esta rota não inclui a bottom navigation bar (empilhada com [MesclaMaterialRoute]).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/startup_detail_mock.dart';
import '../models/catalog_startup.dart';
import '../models/startup_detail_load_state.dart';
import '../services/socio_firestore_mapper.dart';
import '../services/startup_catalog_functions_service.dart';
import '../widgets/detail_demo_video_section.dart';
import '../widgets/mescla_capture_progress_bar.dart';
import '../widgets/mescla_detail_header.dart';
import '../widgets/mescla_pdf_section_card.dart';
import '../widgets/startup_logo_avatar.dart';
import '../../navigation/mescla_material_route.dart';
import '../../auth/services/user_firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/valuation_evolution_chart_card.dart';

import 'socio_detail_screen.dart';
import 'startup_qa_full_screen.dart';

part 'startup_detail_screen_widgets.dart';

/// Tela completa de detalhes da startup.
///
/// Com [catalog.firestoreId] preenchido, os dados vêm da callable `listStartups`
/// (`includeDetail`). Sem ID ou em testes, usa [detailLoadStreamForTesting] ou [startupDetailFor] local.
class StartupDetailScreen extends StatefulWidget {
  const StartupDetailScreen({
    super.key,
    required this.catalog,
    this.catalogFunctionsService,
    this.detailLoadStreamForTesting,
    this.prefetchDetailFuture,
  });

  /// Startup tocada no catálogo (mantém identidade visual e o ID do documento, se houver).
  final CatalogStartup catalog;

  /// Injecção opcional da callable (testes / DI).
  final StartupCatalogFunctionsService? catalogFunctionsService;

  /// Injeta um stream fixo em `flutter test` (sem Firebase).
  final Stream<StartupDetailLoadState>? detailLoadStreamForTesting;

  /// [Future] já iniciado **antes** do [Navigator.push] (pré-carga do detalhe).
  ///
  /// Evita começar o pedido só no [initState] deste widget — ganha o tempo da
  /// animação de transição. Se for `null`, o estado normal chama
  /// [StartupCatalogFunctionsService.fetchStartupDetail] aqui.
  final Future<StartupDetailViewData?>? prefetchDetailFuture;

  @override
  State<StartupDetailScreen> createState() => _StartupDetailScreenState();
}

class _StartupDetailScreenState extends State<StartupDetailScreen> {
  /// Máximo de perguntas na pré-visualização do card (lista completa em [StartupQaFullScreen]).
  static const int _kPreviewPerguntasMax = 3;

  /// Período ativo no gráfico "Evolução" — rótulos do PDF §5.4.
  ValuationPeriod _valuationPeriod = ValuationPeriod.mensal;

  /// Estado de favorito persistido em `users/{uid}.favoriteStartupIds`.
  bool _onWishlist = false;
  bool _wishlistBusy = false;

  /// Modo teste: stream fixo injetado.
  Stream<StartupDetailLoadState>? _detailStream;

  /// Mock instantâneo antes do primeiro frame do stream (só modos stream).
  StartupDetailLoadState? _streamInitialData;

  /// Modo produção com `firestoreId`: resposta da callable `listStartups`.
  Future<StartupDetailViewData?>? _detailFuture;

  StartupCatalogFunctionsService get _catalogFunctionsService =>
      widget.catalogFunctionsService ?? StartupCatalogFunctionsService();

  @override
  void initState() {
    super.initState();
    if (widget.detailLoadStreamForTesting != null) {
      _streamInitialData = null;
      _detailStream = widget.detailLoadStreamForTesting;
      _detailFuture = null;
    } else if (widget.catalog.firestoreId != null) {
      _detailStream = null;
      _streamInitialData = null;
      _detailFuture =
          widget.prefetchDetailFuture ??
          _catalogFunctionsService.fetchStartupDetail(
            widget.catalog.firestoreId!,
          );
    } else {
      final ready = StartupDetailReady(startupDetailFor(widget.catalog));
      _streamInitialData = ready;
      _detailStream = Stream<StartupDetailLoadState>.value(ready);
      _detailFuture = null;
    }
    _loadWishlistState();
  }

  Future<void> _loadWishlistState() async {
    final startupId = widget.catalog.firestoreId?.trim();
    if (startupId == null || startupId.isEmpty) {
      return;
    }
    try {
      final fav = await UserFirestoreService.isStartupFavorited(startupId);
      if (!mounted) {
        return;
      }
      setState(() => _onWishlist = fav);
    } catch (_) {
      // Em falha de rede/permissão, mantém o estado local padrão (não favorito).
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

  void _refreshDetail() {
    final startupId = widget.catalog.firestoreId?.trim();
    if (_detailFuture == null || startupId == null || startupId.isEmpty) {
      return;
    }
    setState(() {
      _detailFuture = _catalogFunctionsService.fetchStartupDetail(startupId);
    });
  }

  Future<void> _showCreateQuestionDialog(StartupDetailViewData detail) async {
    final startupId = detail.catalog.firestoreId?.trim();
    if (startupId == null || startupId.isEmpty) {
      _snack('Não foi possível identificar a startup.');
      return;
    }

    final _NovaPerguntaDialogResult? result =
        await showDialog<_NovaPerguntaDialogResult>(
          context: context,
          builder: (dialogContext) => _NovaPerguntaDialog(
            canSelectVisibility: detail.canSelectQuestionVisibility,
          ),
        );

    if (result == null || !mounted) {
      return;
    }

    try {
      await _catalogFunctionsService.createStartupQuestion(
        startupId: startupId,
        text: result.text,
        isPrivate: result.isPrivate && detail.canSelectQuestionVisibility,
      );
      if (!mounted) {
        return;
      }
      _snack('Pergunta enviada com sucesso.');
      _refreshDetail();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _snack(StartupCatalogFunctionsService.messageForError(e));
    }
  }

  void _abrirListaCompletaPerguntas(StartupDetailViewData detail) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => StartupQaFullScreen(
          publicQa: detail.publicQa,
          investorQa: detail.investorQa,
          canUseInvestorFilter: detail.canViewInvestorQuestions,
        ),
      ),
    );
  }

  Future<void> _toggleWishlist() async {
    if (_wishlistBusy) return;
    final startupId = widget.catalog.firestoreId?.trim();
    if (startupId == null || startupId.isEmpty) {
      _snack('Não foi possível favoritar esta startup.');
      return;
    }
    final next = !_onWishlist;
    setState(() {
      _onWishlist = next;
      _wishlistBusy = true;
    });
    try {
      await UserFirestoreService.setStartupFavorite(
        startupId: startupId,
        favorite: next,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _onWishlist = !next);
      _snack('Não foi possível atualizar os favoritos.');
    } finally {
      if (mounted) {
        setState(() => _wishlistBusy = false);
      }
    }
  }

  void _redirectToBalcao(CatalogStartup startup) {
    // Retorna a startup para quem fez o push (CatalogScreen).
    // O CatalogScreen repassa via callback até o DashboardScreen trocar para o Balcão.
    Navigator.of(context).pop<CatalogStartup>(startup);
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

  /// Corpo scrollável comum ao [FutureBuilder] (callable) e ao [StreamBuilder] (teste/mock).
  Widget _buildDetailScrollView(
    ThemeData theme,
    Color primary,
    StartupDetailViewData detail,
  ) {
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
            wishlistBusy: _wishlistBusy,
            onToggleWishlist: _toggleWishlist,
            onInvest: () => _redirectToBalcao(detail.catalog),
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
                MesclaMaterialRoute.fadeSlide<void>(
                  (context) => SocioDetailScreen(
                    data: resolveSocioDetailForTeamMember(member),
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
            child: Builder(
              builder: (context) {
                final previas = detail.publicQa
                    .take(_kPreviewPerguntasMax)
                    .toList();
                final mostrarVerTodas =
                    detail.publicQa.length > _kPreviewPerguntasMax ||
                    (detail.canViewInvestorQuestions &&
                        detail.investorQa.isNotEmpty);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (previas.isEmpty)
                      Text(
                        'Ainda não há perguntas públicas.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      )
                    else
                      ...previas.map((qa) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'P: ${qa.question}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'R: ${qa.answer}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.secondaryLabel(theme),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (mostrarVerTodas)
                            TextButton(
                              onPressed: () =>
                                  _abrirListaCompletaPerguntas(detail),
                              child: const Text('Ver todas'),
                            ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () =>
                                _showCreateQuestionDialog(detail),
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Fazer pergunta'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
            child: _detailFuture != null
                ? FutureBuilder<StartupDetailViewData?>(
                    future: _detailFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              StartupCatalogFunctionsService.messageForError(
                                snapshot.error!,
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.secondaryLabel(theme),
                              ),
                            ),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final StartupDetailViewData? detail = snapshot.data;
                      if (detail == null) {
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
                      return _buildDetailScrollView(theme, primary, detail);
                    },
                  )
                : StreamBuilder<StartupDetailLoadState>(
                    initialData: _streamInitialData,
                    stream: _detailStream!,
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
                      return _buildDetailScrollView(theme, primary, detail);
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
