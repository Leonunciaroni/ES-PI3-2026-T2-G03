// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Barra de navegação inferior alinhada ao Figma: fundo branco em cápsula; item
// ativo com pílula roxa (primary) **à volta do ícone e do rótulo** (ambos
// brancos); inativos em cinza, sem realce de fundo.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra inferior “flutuante” (Material branco elevado + margens).
///
/// **Como usar:** o ecrã pai guarda um `int` de `0` a `itemCount - 1` (hoje
/// `0`..`4`) e
/// passa em [selectedIndex]. No [onItemTap] chama-se
/// `setState(() => índice = i)` no pai para redesenhar a UI (o índice visível
/// do [IndexedStack] deve coincidir com o da barra).
///
/// **Índices (Figma):** 0 = INÍCIO, 1 = CARTEIRA, 2 = BALCÃO, 3 = CATÁLOGO,
/// 4 = PERFIL.
///
/// Para o layout completo (gradiente + [IndexedStack] + esta barra), usa
/// [MesclaMainShell] em `mescla_main_shell.dart`.
class MesclaBottomNavBar extends StatelessWidget {
  const MesclaBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
  });

  /// Número de abas; mantém a lista de ícones/labels e o loop no mesmo valor.
  static const int itemCount = 5;

  final int selectedIndex;
  final ValueChanged<int> onItemTap;

  /// Um ícone por aba, na mesma ordem de [_labels] (Figma / Material Icons).
  static const List<IconData> _icons = [
    Icons.home_rounded,
    Icons.account_balance_wallet_outlined,
    Icons.storefront_outlined,
    Icons.grid_view_outlined,
    Icons.person_outline_rounded,
  ];

  static const List<String> _labels = [
    'INÍCIO',
    'CARTEIRA',
    'BALCÃO',
    'CATÁLOGO',
    'PERFIL',
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // Margens laterais: afastam a cápsula das bordas do ecrã.
    // Com 5 itens, o padding interno abaixo fica ligeiramente mais apertado
    // para evitar corte de texto em telas estreitas.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            // [Expanded] em cada _NavItem reparte o espaço em fatias iguais.
            children: [
              for (var i = 0; i < itemCount; i++)
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
    // Cor do ícone e do texto: no ativo, ambos brancos sobre a pílula roxa; no
    // inativo, cinza de marca ([AppColors.navBarInactive]).
    final contentColor = isActive ? Colors.white : inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        // Raio alinhado ao recorte de splash do toque.
        borderRadius: BorderRadius.circular(20),
        // Centraliza a pílula dentro da fatia horizontal deste item.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Align(
            alignment: Alignment.center,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isActive ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                // Espaçamento mínimo entre o conteúdo e a borda roxa (Figma).
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: contentColor,
                      // Tamanho um pouco menor com 5 ícones na mesma largura.
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: contentColor,
                            fontWeight: FontWeight.w700,
                            // Menos rótulo longo: leve compactação para 5 abas.
                            letterSpacing: 0.2,
                            fontSize: 9,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
