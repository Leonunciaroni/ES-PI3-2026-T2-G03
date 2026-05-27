// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
// Autor da lógica das perguntas e respostas: Miguel Costacurta - 25003110
// Lista completa de perguntas e respostas da startup. Investidores podem filtrar
// Todas / Públicas / Privadas; demais usuários veem apenas as públicas.

import 'package:flutter/material.dart';

import '../data/startup_detail_mock.dart';
import '../../theme/app_colors.dart';

/// Filtro da lista (só aplicado quando [StartupQaFullScreen.canUseInvestorFilter] é true).
enum StartupQaVisibilityFilter {
  all,
  publicOnly,
  privateOnly,
}

/// Ecrã com todas as perguntas; filtro M3 apenas para investidores.
class StartupQaFullScreen extends StatefulWidget {
  const StartupQaFullScreen({
    super.key,
    required this.publicQa,
    required this.investorQa,
    required this.canUseInvestorFilter,
  });

  final List<StartupPublicQa> publicQa;
  final List<StartupPublicQa> investorQa;

  /// `true` quando o usuário é investidor — mostra [SegmentedButton] de filtro.
  final bool canUseInvestorFilter;

  @override
  State<StartupQaFullScreen> createState() => _StartupQaFullScreenState();
}

class _StartupQaFullScreenState extends State<StartupQaFullScreen> {
  StartupQaVisibilityFilter _filter = StartupQaVisibilityFilter.all;

  List<({StartupPublicQa qa, bool isPrivate})> get _filtered {
    if (!widget.canUseInvestorFilter) {
      return [
        for (final q in widget.publicQa) (qa: q, isPrivate: false),
      ];
    }
    switch (_filter) {
      case StartupQaVisibilityFilter.all:
        return [
          for (final q in widget.publicQa) (qa: q, isPrivate: false),
          for (final q in widget.investorQa) (qa: q, isPrivate: true),
        ];
      case StartupQaVisibilityFilter.publicOnly:
        return [
          for (final q in widget.publicQa) (qa: q, isPrivate: false),
        ];
      case StartupQaVisibilityFilter.privateOnly:
        return [
          for (final q in widget.investorQa) (qa: q, isPrivate: true),
        ];
    }
  }

  String _emptyMessage() {
    if (!widget.canUseInvestorFilter) {
      return 'Não há perguntas públicas.';
    }
    return switch (_filter) {
      StartupQaVisibilityFilter.all => 'Não há perguntas nesta startup.',
      StartupQaVisibilityFilter.publicOnly => 'Não há perguntas públicas.',
      StartupQaVisibilityFilter.privateOnly =>
        'Não há perguntas privadas de investidores.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = _filtered;
    final bodyBg = theme.brightness == Brightness.light
        ? AppColors.gradientBottom
        : AppColors.gradientBottomDark;

    return Scaffold(
      backgroundColor: bodyBg,
      appBar: AppBar(
        title: const Text('Perguntas e respostas'),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.canUseInvestorFilter) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SegmentedButton<StartupQaVisibilityFilter>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  side: BorderSide(color: AppColors.cardDivider(theme)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
                segments: const [
                  ButtonSegment<StartupQaVisibilityFilter>(
                    value: StartupQaVisibilityFilter.all,
                    label: Text('Todas'),
                  ),
                  ButtonSegment<StartupQaVisibilityFilter>(
                    value: StartupQaVisibilityFilter.publicOnly,
                    label: Text('Públicas'),
                  ),
                  ButtonSegment<StartupQaVisibilityFilter>(
                    value: StartupQaVisibilityFilter.privateOnly,
                    label: Text('Privadas'),
                  ),
                ],
                selected: <StartupQaVisibilityFilter>{_filter},
                onSelectionChanged: (Set<StartupQaVisibilityFilter> next) {
                  setState(() => _filter = next.first);
                },
              ),
            ),
          ] else
            const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _emptyMessage(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final entry = items[i];
                      return _QaListTile(
                        qa: entry.qa,
                        showVisibilityBadge:
                            widget.canUseInvestorFilter &&
                            _filter == StartupQaVisibilityFilter.all,
                        isPrivate: entry.isPrivate,
                        primary: scheme.primary,
                        theme: theme,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QaListTile extends StatelessWidget {
  const _QaListTile({
    required this.qa,
    required this.showVisibilityBadge,
    required this.isPrivate,
    required this.primary,
    required this.theme,
  });

  final StartupPublicQa qa;
  final bool showVisibilityBadge;
  final bool isPrivate;
  final Color primary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showVisibilityBadge) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _VisibilityChip(
                  isPrivate: isPrivate,
                  primary: primary,
                  theme: theme,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'P: ${qa.question}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'R: ${qa.answer}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryLabel(theme),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({
    required this.isPrivate,
    required this.primary,
    required this.theme,
  });

  final bool isPrivate;
  final Color primary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final label = isPrivate ? 'Privada' : 'Pública';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
