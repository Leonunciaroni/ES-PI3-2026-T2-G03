// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Layout “logado” partilhado: gradiente Mescla, área segura, cinco painéis e
// [MesclaBottomNavBar]. Evita copiar o mesmo [Scaffold] em cada ecrã.
//
// ## Porque não usamos só [IndexedStack]?
// O [IndexedStack] troca o painel **instantaneamente**. Para uma UX próxima das
// apps grandes, animamos **opacidade + um micro-deslocamento vertical** (o mesmo
// espírito do [MesclaFadeSlidePageTransitionsBuilder] em `app_theme.dart`).
//
// ## Estado preservado
// Todas as abas permanecem **montadas** no [Stack] (como no [IndexedStack]).
// Só a aba ativa recebe toques ([IgnorePointer]).
//
// ## Importante — não uses [TickerMode] aqui para “pausar” abas inativas
// [AnimatedOpacity] e [AnimatedSlide] são animações **implícitas**: precisam de
// ticker enquanto animam. Se desativares o ticker na aba que está a sair no
// mesmo instante em que muda o índice, essa animação **congela** (ex.: opacity
// fica em 1). O ecrã anterior continua pintado por baixo e, como muitas telas
// têm fundos semi-transparentes, vês **dois ecrãs ao mesmo tempo** (overlap).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation/mescla_tab_count.dart';
export '../navigation/mescla_tab_count.dart' show kMesclaMainTabCount;
import '../theme/app_colors.dart';
import 'mescla_bottom_nav_bar.dart';

/// Duração do cruzamento entre separadores (alinhada às transições de rota).
const Duration kMesclaTabSwitchDuration = Duration(milliseconds: 280);

/// Shell com navegação inferior para o fluxo principal após autenticação.
///
/// **Índices:** alinhados com [MesclaBottomNavBar] — 0 Início, 1 Carteira,
/// 2 Balcão, 3 Catálogo, 4 Perfil.
///
/// Telas de autenticação em `lib/auth/screens`, dashboard em `lib/dashboard/screens`;
/// carteira em `lib/carteira/screens`; catálogo em `lib/catalog/screens`.
/// Rotas empurradas (ex.: detalhe da startup) ficam **fora** deste shell.
class MesclaMainShell extends StatelessWidget {
  const MesclaMainShell({
    super.key,
    required this.selectedIndex,
    required this.onNavIndexChanged,
    required this.tabBodies,
  }) : assert(tabBodies.length == kMesclaMainTabCount);

  final int selectedIndex;
  final ValueChanged<int> onNavIndexChanged;

  /// Exatamente [kMesclaMainTabCount] widgets; o visível é o de [selectedIndex].
  final List<Widget> tabBodies;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gradientColors = AppColors.shellGradientColors(brightness);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.shellOverlayStyle(brightness),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: List<Widget>.generate(tabBodies.length, (int i) {
                      final bool ativa = i == selectedIndex;
                      return Positioned.fill(
                        child: ExcludeSemantics(
                          excluding: !ativa,
                          child: IgnorePointer(
                            ignoring: !ativa,
                            child: ClipRect(
                              child: AnimatedSlide(
                                duration: kMesclaTabSwitchDuration,
                                curve: Curves.easeOutCubic,
                                offset: ativa
                                    ? Offset.zero
                                    : const Offset(0, 0.03),
                                child: AnimatedOpacity(
                                  duration: kMesclaTabSwitchDuration,
                                  curve: Curves.easeOutCubic,
                                  opacity: ativa ? 1.0 : 0.0,
                                  child: tabBodies[i],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                MesclaBottomNavBar(
                  selectedIndex: selectedIndex,
                  onItemTap: onNavIndexChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
