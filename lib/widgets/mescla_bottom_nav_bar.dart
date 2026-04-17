// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Barra de navegação inferior alinhada ao dashboard / Figma: fundo branco em
// cápsula; item ativo com retângulo arredondado só atrás do ícone (ícone branco)
// e rótulo em roxo; inativos em cinza.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra inferior “flutuante” (Material branco elevado + margens).
///
/// **Como usar:** o ecrã pai guarda um `int` (0..3) e passa em [selectedIndex].
/// No [onItemTap] chamas `setState(() => índice = i)` para redesenhar a UI.
///
/// **Índices:** 0 = INÍCIO, 1 = BALCÃO, 2 = CATÁLOGO, 3 = PERFIL.
class MesclaBottomNavBar extends StatelessWidget {
  const MesclaBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemTap;

  /// Mesmos ícones que o dashboard original do projeto.
  static const List<IconData> _icons = [
    Icons.home_rounded,
    Icons.account_balance_wallet_outlined,
    Icons.article_outlined,
    Icons.person_outline_rounded,
  ];

  static const List<String> _labels = [
    'INÍCIO',
    'BALCÃO',
    'CATÁLOGO',
    'PERFIL',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < 4; i++)
                _NavItem(
                  icon: _icons[i],
                  label: _labels[i],
                  isActive: selectedIndex == i,
                  activeColor: primary,
                  inactiveColor: AppColors.navBarInactive,
                  onTap: () => onItemTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    // Igual ao dashboard: ativo → texto roxo; inativo → texto cinza.
    final labelColor = isActive ? activeColor : inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Só o ícone fica sobre o fundo roxo (não o rótulo).
              Container(
                width: 48,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
