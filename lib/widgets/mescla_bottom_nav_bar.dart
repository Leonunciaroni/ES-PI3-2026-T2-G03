// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Barra de navegação inferior conforme Figma: fundo branco em cápsula, item ativo
// com pílula roxa envolvendo ícone + rótulo (ambos brancos), inativos em cinza.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra inferior “flutuante” (Material branco elevado + margens).
///
/// **Como usar:** o ecrã pai guarda um `int` (0..3) e passa em [selectedIndex].
/// No [onItemTap] chamas `setState(() => índice = i)` para redesenhar a UI e
/// trocar o conteúdo (ex.: [IndexedStack] por cima desta barra).
///
/// **Índices:** 0 = INÍCIO, 1 = CARTEIRA, 2 = CATÁLOGO, 3 = PERFIL.
class MesclaBottomNavBar extends StatelessWidget {
  const MesclaBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
  });

  /// Qual separador está selecionado (o pai é a fonte da verdade).
  final int selectedIndex;

  /// Chamado quando o utilizador toca num item; recebe o novo índice.
  final ValueChanged<int> onItemTap;

  /// Ícones em estilo *outline*, alinhados ao Figma (casa, carteira, lista, pessoa).
  static const List<IconData> _icons = [
    Icons.home_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.article_outlined,
    Icons.person_outline_rounded,
  ];

  /// Rótulos em maiúsculas, como no Figma (segundo item é CARTEIRA, não BALCÃO).
  static const List<String> _labels = [
    'INÍCIO',
    'CARTEIRA',
    'CATÁLOGO',
    'PERFIL',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Roxo da marca vem do tema (sincronizado com AppColors.seedPurple no MaterialApp).
    final primary = theme.colorScheme.primary;

    // Margens laterais e em baixo criam o efeito “flutuante” sobre o fundo do ecrã.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          // Row com 4 filhos Expanded: cada item ocupa a mesma largura disponível.
          child: Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: _NavItem(
                    icon: _icons[i],
                    label: _labels[i],
                    isActive: selectedIndex == i,
                    activeColor: primary,
                    inactiveColor: AppColors.navBarInactive,
                    onTap: () => onItemTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Um único separador: ícone + texto; estado visual ativo vs inativo.
///
/// Mantemos esta classe **privada** (prefixo `_`) porque só é usada aqui dentro
/// do mesmo ficheiro — não precisa de aparecer na API pública do pacote.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Estilo base do rótulo (tamanho pequeno, negrito, espaçamento entre letras).
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
          fontSize: 10,
        );

    // Conteúdo: ícone em cima, texto em baixo (coluna vertical do Figma).
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          color: isActive ? Colors.white : inactiveColor,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle?.copyWith(
            color: isActive ? Colors.white : inactiveColor,
          ),
        ),
      ],
    );

    // Ativo: [DecoratedBox] com cantos 999 = cápsula; inativo: só padding vertical
    // para alinhar visualmente a altura com o vizinho selecionado.
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: isActive
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: content,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: content,
            ),
    );

    // [InkWell] dá feedback de toque (ripple) dentro da área do item.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: padded,
    );
  }
}
