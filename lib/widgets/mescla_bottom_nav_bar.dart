// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Barra de navegação inferior (Figma): cápsula branca, 5 itens, pílula roxa
// no selecionado. Comentários abaixo são didáticos — explicam o “porquê” do
// layout, como se estivéssemos a rever o código na aula.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// --- Widget “público” (é este que o resto do app importa) ---

/// Barra de baixo com 5 abas (Início, Carteira, Balcão, Catálogo, Perfil).
///
/// O [DashboardScreen] (ou outro ecrã) guarda um `int` com o índice da aba
/// ativa e passa aqui em [selectedIndex]. Quando o utilizador toca num item,
/// o Flutter chama [onItemTap] com o índice novo — normalmente fazes
/// `setState` lá no pai e o [IndexedStack] muda a tela.
class MesclaBottomNavBar extends StatelessWidget {
  const MesclaBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
  });

  static const int itemCount = 5;

  final int selectedIndex;
  final ValueChanged<int> onItemTap;

  // Cada aba tem um par (ícone, texto). A ordem tem de ser a mesma nas duas
  // listas, senão o ícone da Carteira podia aparecer em cima da palavra Balcão.
  static const List<IconData> _icons = [
    Icons.home_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.storefront_outlined,
    Icons.grid_view_outlined,
    Icons.person_outline,
  ];

  static const List<String> _labels = [
    'INÍCIO',
    'CARTEIRA',
    'BALCÃO',
    'CATÁLOGO',
    'PERFIL',
  ];

  // Altura fixa (em dp = unidade lógica que o Flutter escala por ecrã) da faixa
  // dos cinco itens, como no Figma. Assim a pílula ativa fica alinhada; sem
  // isso, o layout escolhia alturas sozinho e o destaque saía do sítio.
  static const double _faixaItensAltura = 56;

  // “Respiro” em cima e embaixo do chip roxo, dentro desta faixa. É o ar
  // branco fino que separa a pílula do rebordo da cápsula.
  static const double _margemChipVertical = 4;

  @override
  Widget build(BuildContext context) {
    // A cor primária vem do Theme (no main.dart já pusemos o roxo da marca).
    // Uso a mesma no fundo ativo e na sombra, para tudo bater certo.
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final shell = AppColors.bottomNavBarShell(theme);
    final isDark = theme.brightness == Brightness.dark;
    // No escuro a cápsula usa [AppColors.gradientBottomDark] (igual ao shell);
    // sombra neutra e leve — evita “glow” roxo e halo forte no mesmo preto.
    final sombra = isDark
        ? Colors.black.withValues(alpha: 0.24)
        : primary.withValues(alpha: 0.2);

    // Padding fora: afasta a barra das laterais do telemóvel e deixa espaço
    // embaixo (senão a cápsula colava na borda da tela).
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        // Miolo do mesmo material que o resto dos cartões (light = branco Figma).
        decoration: BoxDecoration(
          color: shell,
          // borderRadius bem grande = forma de cápsula/estádio (parece um
          // comprimido). Se fosse 8 ou 12, ficava um retângulo só ligeiramente
          // redondo, não a barra "redondinha" do desenho.
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: sombra,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        // Dentro, mais um padding: o conteúdo (ícones) não encosta no branco
        // do rebordo; isso dá a sensação de que a cápsula "respira" por dentro.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          // SizedBox com height fixa: força a Row a ter exatamente esta altura.
          // Assim, quando o item está ativo, a gente sabe de antemão quanto
          // espaço vertical existe para desenhar o roxo.
          child: SizedBox(
            height: _faixaItensAltura,
            child: Row(
              children: [
                // for + Expanded: as 5 abas partilham a largura em partes
                // iguais. Sem Expanded, tudo se amontoava à esquerda ou estourava.
                for (var i = 0; i < itemCount; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _icons[i],
                      label: _labels[i],
                      isActive: selectedIndex == i,
                      trackHeight: _faixaItensAltura,
                      chipVertMargin: _margemChipVertical,
                      activeColor: primary,
                      inactiveColor: AppColors.bottomNavInactive(theme),
                      onTap: () => onItemTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Cada célula: um ícone, um rótulo, toque, estado ativo ou não ---

/// Um item da barra. Se [isActive] for true, desenha a pílula roxa; se não,
/// só a coluna cinza, sem fundo.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.trackHeight,
    required this.chipVertMargin,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final double trackHeight;
  final double chipVertMargin;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Uma cor só para tudo o que “é conteúdo” (ícone + letras). Ativo: branco
    // em cima do roxo. Inativo: o cinza do design system.
    final contentColor = isActive ? Colors.white : inactiveColor;

    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: contentColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          fontSize: 9.5,
        );

    // Column porque no Figma o ícone vem em cima e o texto em baixo, centrados.
    // mainAxisSize.min evita a coluna a ocupar mais altura do que o necessário.
    final coluna = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: contentColor, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: textStyle,
        ),
      ],
    );

    // Matemática simples: a faixa tem [trackHeight] de alto; tiro a margem
    // de cima e a de baixo, e o que sobra é a altura certa do retângulo roxo
    // (fica quase a encher a faixa, como no desenho).
    final alturaRoxa = trackHeight - 2 * chipVertMargin;

    // Material + InkWell: o Material em transparente deixa passar a cor do pai,
    // mas o InkWell precisa dele para desenhar o efeito de toque (ripple).
    // Se não tivéssemos InkWell, o onTap funcionava, mas o utilizador não via
    // feedback visual ao tocar.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Center(
          child: isActive
              ? ConstrainedBox(
                  // Mínimo de largura: textos curtos (ex. INÍCIO) não encolhem a
                  // pílula demais. min/max na mesma altura: o roxo vira um bloco
                  // de altura fixa (não “cresce” com o texto e parte o layout).
                  constraints: BoxConstraints(
                    minWidth: 72,
                    minHeight: alturaRoxa,
                    maxHeight: alturaRoxa,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      // Center: ícone+texto ficam ao meio do retângulo roxo, não
                      // colados a um dos cantos.
                      child: Center(child: coluna),
                    ),
                  ),
                )
              : Padding(
                  // Inativo: mesma “respiração” vertical que a margem do ativo,
                  // para o cinza alinhar visualmente com a posição do conteúdo
                  // quando a aba ao lado liga o roxo.
                  padding: EdgeInsets.symmetric(vertical: chipVertMargin),
                  child: coluna,
                ),
        ),
      ),
    );
  }
}
