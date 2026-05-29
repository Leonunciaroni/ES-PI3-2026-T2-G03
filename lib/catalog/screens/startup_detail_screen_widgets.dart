// Autor principal: Miguel Costacurta - 25003110

part of 'startup_detail_screen.dart';

class _MainInfoCard extends StatelessWidget {
  const _MainInfoCard({
    required this.data,
    required this.primary,
    required this.onWishlist,
    required this.wishlistBusy,
    required this.onToggleWishlist,
    required this.onInvest,
  });

  final StartupDetailViewData data;
  final Color primary;
  final bool onWishlist;
  final bool wishlistBusy;
  final VoidCallback onToggleWishlist;
  final VoidCallback onInvest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = data.catalog;

    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(kMesclaDetailCardRadius),
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
                StartupLogoAvatar(
                  logoPath: c.logoPath,
                  fallbackColor: c.logoColor,
                  fallbackIcon: c.logoIcon,
                  size: 52,
                  borderRadius: 14,
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
                          color: theme.colorScheme.onSurface,
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
                color: AppColors.secondaryLabel(theme),
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
                    onPressed: wishlistBusy ? null : onToggleWishlist,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.themeMutedSurface(theme),
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
        borderRadius: BorderRadius.circular(kMesclaDetailCardRadius),
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
          MesclaCaptureProgressBar(
            value: progress,
            trackColor: Colors.white.withValues(alpha: 0.22),
            fillColor: Colors.white,
            height: 10,
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
  });

  final String roundLabel;
  final String headline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(kMesclaDetailCardRadius),
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
                color: AppColors.secondaryLabel(theme),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              headline,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
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
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(kMesclaDetailCardRadius),
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
                color: theme.colorScheme.onSurface,
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
                  color: AppColors.secondaryLabel(theme),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                m.value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
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
      color: AppColors.themeMutedSurface(theme),
      borderRadius: BorderRadius.circular(kMesclaDetailCardRadius),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Informações da Empresa',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
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
                color: AppColors.secondaryLabel(theme),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"${data.missionQuote}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.secondaryLabel(theme),
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
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
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
  const _TeamCard({
    required this.members,
    required this.initialsFor,
    this.onMemberTap,
  });

  final List<StartupTeamMember> members;
  final String Function(String) initialsFor;

  /// Abre a ficha do membro (mock rico ou resumo a partir do Firestore).
  final void Function(StartupTeamMember member)? onMemberTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (members.isEmpty) return const SizedBox.shrink();
    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(kMesclaDetailCardRadius),
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
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TeamMemberTile(
                  member: m,
                  initialsFor: initialsFor,
                  theme: theme,
                  onSaberMais:
                      onMemberTap != null ? () => onMemberTap!(m) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Uma linha da lista com CTA **Saber mais** à direita (design alinhado ao Figma).
class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({
    required this.member,
    required this.initialsFor,
    required this.theme,
    this.onSaberMais,
  });

  final StartupTeamMember member;
  final String Function(String) initialsFor;
  final ThemeData theme;
  final VoidCallback? onSaberMais;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: member.avatarColor,
          child: Text(
            initialsFor(member.name),
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
                member.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                member.role,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                ),
              ),
            ],
          ),
        ),
        if (onSaberMais != null)
          TextButton(
            onPressed: onSaberMais,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.linkAccent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Saber mais'),
          ),
      ],
    );
  }
}

/// Resultado do diálogo [_NovaPerguntaDialog]: texto e visibilidade escolhidos.
final class _NovaPerguntaDialogResult {
  const _NovaPerguntaDialogResult({
    required this.text,
    required this.isPrivate,
  });

  final String text;
  final bool isPrivate;
}

/// Diálogo com ciclo de vida próprio: o [TextEditingController] é criado em
/// [initState] e libertado em [dispose], evitando assert `_dependents.isEmpty`
/// ao fechar o [AlertDialog] (ex.: com [SegmentedButton] / foco do teclado).
class _NovaPerguntaDialog extends StatefulWidget {
  const _NovaPerguntaDialog({required this.canSelectVisibility});

  final bool canSelectVisibility;

  @override
  State<_NovaPerguntaDialog> createState() => _NovaPerguntaDialogState();
}

class _NovaPerguntaDialogState extends State<_NovaPerguntaDialog> {
  late final TextEditingController _textController;
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onEnviar() {
    final t = _textController.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite uma pergunta antes de enviar.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _NovaPerguntaDialogResult(text: _textController.text, isPrivate: _isPrivate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final searchFill = AppColors.searchFieldFillForTheme(theme);
    const fieldRadius = 16.0;

    InputBorder outlineBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return AlertDialog(
      icon: Icon(
        Icons.chat_bubble_outline_rounded,
        color: scheme.primary,
        size: 28,
      ),
      iconPadding: const EdgeInsets.only(top: 16, bottom: 4),
      title: Text(
        'Nova pergunta',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Sua pergunta',
                hintText: 'O que você gostaria de saber?',
                alignLabelWithHint: true,
                filled: true,
                fillColor: searchFill,
                border: outlineBorder(searchFill),
                enabledBorder: outlineBorder(searchFill),
                focusedBorder: outlineBorder(scheme.primary),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            SizedBox(height: widget.canSelectVisibility ? 24 : 16),
            if (widget.canSelectVisibility) ...[
              Text(
                'Visibilidade',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pública: todos veem. Privada: apenas investidores da startup.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppColors.themeMutedSurface(theme),
                  foregroundColor: scheme.onSurface,
                  selectedBackgroundColor: scheme.primary,
                  selectedForegroundColor: scheme.onPrimary,
                  side: BorderSide(color: AppColors.cardDivider(theme)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  visualDensity: VisualDensity.standard,
                ),
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Pública'),
                    tooltip: 'Visível para todos',
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Privada'),
                    tooltip: 'Somente investidores desta startup',
                  ),
                ],
                selected: <bool>{_isPrivate},
                onSelectionChanged: (Set<bool> selected) {
                  setState(() => _isPrivate = selected.first);
                },
              ),
            ] else
              Text(
                'Sua pergunta será pública e visível para todos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: scheme.primary,
          ),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _onEnviar,
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
