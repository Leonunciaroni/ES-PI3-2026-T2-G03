// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// ## Fluxo
// O utilizador toca em **Saber mais** em [StartupDetailScreen] → esta rota
// recebe um [SocioDetailViewData]. Esse objeto é montado em
// [socioDetailForTeamMember]: ou perfil **rico** (constantes tipo
// [kSocioMockRicardoSilveira] nos templates de startup) ou perfil **placeholder**
// com [SocioDetailViewData.isMockPlaceholder] == true, para mostrar **todas**
// as secções com texto fictício até existir mapeamento Firestore.
//
// ## Layout
// 1. [MesclaDetailHeader] — voltar + logo (partilhado com a tela da startup).
// 2. Opcional: faixa âmbar se `isMockPlaceholder` — avisa que só nome/papel
//    são “reais” da lista; o resto é exemplo.
// 3. [_IdentityCard] — foto/iniciais, nome, cargo, startup, participação.
// 4. Vários [MesclaPdfSectionCard] — superfície por tema (bio, LinkedIn,
//    formação, …). Cada `if` no [build] só acrescenta a secção se o campo
//    correspondente tiver conteúdo (lista não vazia ou `String` não nula).
//
// Quando integrarem o Firestore, basta preencher [SocioDetailViewData] a partir
// do mapa de cada sócio — **não é obrigatório** alterar esta tela se os nomes
// dos campos do modelo forem os mesmos.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/startup_detail_mock.dart';
import '../widgets/mescla_detail_header.dart';
import '../widgets/mescla_pdf_section_card.dart';
import '../../theme/app_colors.dart';

/// Espaço vertical entre cada [MesclaPdfSectionCard] consecutivo.
const double _kSectionGap = 14;

/// Diâmetro lógico do avatar = 2 × este raio (ver [_IdentityCard]).
const double _kHeroAvatarRadius = 48;

/// Evita desenhar títulos de secção com strings vazias ou só espaços.
bool _hasText(String? s) => s != null && s.trim().isNotEmpty;

/// Gera iniciais para o círculo quando não há foto ou o download falha.
String _initialsFromFullName(String fullName) {
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

/// Ficha do sócio / mentor — cada secção corresponde a um grupo de campos
/// do modelo (apresentação, formação, experiência, papel na startup, etc.).
class SocioDetailScreen extends StatelessWidget {
  const SocioDetailScreen({
    super.key,
    required this.data,
    required this.startupDisplayName,
  });

  final SocioDetailViewData data;
  final String startupDisplayName;

  /// Feedback rápido quando o URL do LinkedIn é inválido ou o plugin falha.
  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Abre o browser externo — padrão igual ao vídeo demo na startup.
  Future<void> _openLinkedIn(BuildContext context, String? raw) async {
    if (raw == null || raw.trim().isEmpty) {
      _snack(context, 'Link não disponível.');
      return;
    }
    String normalized = raw.trim();
    if (!normalized.contains('://')) {
      normalized = 'https://$normalized';
    }
    final Uri? uri = Uri.tryParse(normalized);
    if (uri == null) {
      _snack(context, 'URL inválida.');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      if (!ok) _snack(context, 'Não foi possível abrir o link.');
    } on MissingPluginException {
      if (!context.mounted) return;
      _snack(
        context,
        'Plugin de link não carregado. Rode: flutter clean && flutter pub get',
      );
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Erro ao abrir: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final initials = _initialsFromFullName(data.fullName);

    // Lista linear de widgets: vamos dar `add` / `addSection` para ler de cima
    // a baixo como aparece no ecrã (facilita manutenção da ordem das secções).
    final sectionWidgets = <Widget>[
      const MesclaDetailHeader(),
      if (data.isMockPlaceholder) ...[
        const SizedBox(height: 12),
        const _MockDataNoticeBanner(),
      ],
      SizedBox(height: data.isMockPlaceholder ? 16 : 20),
      _IdentityCard(
        data: data,
        initials: initials,
        startupDisplayName: startupDisplayName,
        primary: primary,
      ),
    ];

    /// Encapsula o padrão “espaçamento + cartão branco” das secções do PDF §5.2.
    void addSection(String title, Widget child) {
      sectionWidgets
        ..add(const SizedBox(height: _kSectionGap))
        ..add(MesclaPdfSectionCard(title: title, child: child));
    }

    // Cada bloco abaixo corresponde a um campo (ou grupo) em [SocioDetailViewData].
    // Na integração Firestore, campos vazios = secção omitida automaticamente.

    if (_hasText(data.shortBio)) {
      addSection(
        'Apresentação institucional',
        Text(
          data.shortBio!.trim(),
          style: _bodyStyle(theme),
        ),
      );
    }

    if (_hasText(data.linkedinUrl)) {
      addSection(
        'LinkedIn',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Perfil público profissional para rede e histórico.',
              style: _bodyStyle(theme),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openLinkedIn(context, data.linkedinUrl),
                icon: Icon(Icons.link_rounded, color: primary),
                label: Text(
                  'Abrir LinkedIn',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasText(data.academicBackground) || _hasText(data.mainInstitution)) {
      addSection(
        'Formação acadêmica',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasText(data.academicBackground)) ...[
              _Subheading(label: 'Curso / formação'),
              Text(data.academicBackground!.trim(), style: _bodyStyle(theme)),
              if (_hasText(data.mainInstitution)) const SizedBox(height: 14),
            ],
            if (_hasText(data.mainInstitution)) ...[
              _Subheading(label: 'Instituição principal'),
              Text(data.mainInstitution!.trim(), style: _bodyStyle(theme)),
            ],
          ],
        ),
      );
    }

    if (data.specialties.isNotEmpty) {
      addSection(
        'Especialidades e áreas de atuação',
        Text(
          data.specialties.join(' · '),
          style: _bodyStyle(theme),
        ),
      );
    }

    if (_hasText(data.marketExperience)) {
      addSection(
        'Tempo de experiência no mercado',
        Text(
          data.marketExperience!.trim(),
          style: _bodyStyle(theme),
        ),
      );
    }

    if (data.priorRoles.isNotEmpty) {
      addSection(
        'Experiências anteriores relevantes',
        _BulletList(lines: data.priorRoles, theme: theme),
      );
    }

    if (_hasText(data.responsibilities)) {
      addSection(
        'Responsabilidades na startup',
        Text(
          data.responsibilities!.trim(),
          style: _bodyStyle(theme),
        ),
      );
    }

    if (_hasText(data.strategicEdge)) {
      addSection(
        'Diferencial estratégico',
        Text(
          data.strategicEdge!.trim(),
          style: _bodyStyle(theme),
        ),
      );
    }

    if (data.skills.isNotEmpty) {
      addSection(
        'Competências principais',
        _SkillChips(labels: data.skills, primary: primary),
      );
    }

    if (data.highlights.isNotEmpty) {
      addSection(
        'Projetos e conquistas relevantes',
        _BulletList(lines: data.highlights, theme: theme),
      );
    }

    if (data.certifications.isNotEmpty) {
      addSection(
        'Certificações',
        _BulletList(lines: data.certifications, theme: theme),
      );
    }

    if (data.languages.isNotEmpty) {
      addSection(
        'Idiomas',
        _BulletList(lines: data.languages, theme: theme),
      );
    }

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sectionWidgets,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estilo de corpo reutilizado nos parágrafos das secções.
TextStyle? _bodyStyle(ThemeData theme) {
  return theme.textTheme.bodyMedium?.copyWith(
    color: AppColors.secondaryLabel(theme),
    height: 1.4,
  );
}

/// Aviso quando [SocioDetailViewData.isMockPlaceholder] é true — explica que
/// os textos longos são exemplos até o backend preencher os campos reais.
class _MockDataNoticeBanner extends StatelessWidget {
  const _MockDataNoticeBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Âmbar legível no claro e no escuro (evita faixa amarela em cima de fundo preto).
    final bg = isDark ? const Color(0xFF3D2E0A) : const Color(0xFFFFFBEB);
    final fg = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
    final iconColor =
        isDark ? const Color(0xFFFBBF24) : theme.colorScheme.primary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 22,
              color: iconColor.withValues(alpha: isDark ? 0.95 : 0.85),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pré-visualização com dados fictícios. O nome e o papel vêm da '
                'lista da startup; os dados restantes usam texto de exemplo até '
                'a integração com o Firestore.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rótulo pequeno dentro de uma secção (subtópico).
class _Subheading extends StatelessWidget {
  const _Subheading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.secondaryLabel(theme),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Primeiro cartão de identidade: resume **quem** é a pessoa no contexto da startup.
/// O LinkedIn fica numa secção à parte para não competir visualmente com o nome.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.data,
    required this.initials,
    required this.startupDisplayName,
    required this.primary,
  });

  final SocioDetailViewData data;
  final String initials;
  final String startupDisplayName;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = data.photoUrl?.trim();

    return Material(
      color: AppColors.themeCardSurface(theme),
      borderRadius: BorderRadius.circular(kMesclaDetailCardRadius),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // [Image.network] tenta a URL; se falhar (offline, 404), cai nas iniciais.
                ClipOval(
                  child: url != null && url.isNotEmpty
                      ? Image.network(
                          url,
                          width: _kHeroAvatarRadius * 2,
                          height: _kHeroAvatarRadius * 2,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _InitialsAvatar(
                            color: data.avatarFallbackColor,
                            initials: initials,
                          ),
                        )
                      : _InitialsAvatar(
                          color: data.avatarFallbackColor,
                          initials: initials,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.fullName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.listRoleLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        startupDisplayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Subheading(label: 'Participação societária / papel'),
                      Text(
                        data.participationLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryLabel(theme),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.color,
    required this.initials,
  });

  final Color color;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kHeroAvatarRadius * 2,
      height: _kHeroAvatarRadius * 2,
      color: color,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    );
  }
}

/// Lista com marcadores — usada em experiências, conquistas, certificações, etc.
class _BulletList extends StatelessWidget {
  const _BulletList({required this.lines, required this.theme});

  final List<String> lines;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${line.trim()}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  height: 1.35,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// [Chip]s com cor derivada do `primary` do tema — alinhado à marca Mescla.
class _SkillChips extends StatelessWidget {
  const _SkillChips({required this.labels, required this.primary});

  final List<String> labels;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels
          .map(
            (s) => Chip(
              label: Text(s),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: primary.withValues(alpha: 0.08),
              side: BorderSide(color: primary.withValues(alpha: 0.2)),
              labelStyle: TextStyle(
                color: primary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          )
          .toList(),
    );
  }
}
