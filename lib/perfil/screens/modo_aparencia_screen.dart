// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Modo de aparência: Claro, Escuro ou Padrão do sistema. A escolha aplica-se logo
// via [themeModeController] e fica guardada em [shared_preferences] (reabertura).

import 'package:flutter/material.dart';

import '../../theme/theme_mode_controller.dart';
import '../widgets/mescla_subpage_scaffold.dart';

class ModoAparenciaScreen extends StatelessWidget {
  const ModoAparenciaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;

    return MesclaSubpageScaffold(
      title: 'Modo de Aparência',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // [ListenableBuilder] reconstrói a lista ao mudar a preferência.
          ListenableBuilder(
            listenable: themeModeController,
            builder: (context, _) {
              final group = themeModeController.themeMode;
              return Material(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    _TemaOpTile(
                      titulo: 'Claro',
                      selecionado: group == ThemeMode.light,
                      corCheck: primary,
                      onTap: () =>
                          themeModeController.setMode(ThemeMode.light),
                    ),
                    const Divider(height: 1),
                    _TemaOpTile(
                      titulo: 'Escuro',
                      selecionado: group == ThemeMode.dark,
                      corCheck: primary,
                      onTap: () => themeModeController.setMode(ThemeMode.dark),
                    ),
                    const Divider(height: 1),
                    _TemaOpTile(
                      titulo: 'Padrão do sistema',
                      selecionado: group == ThemeMode.system,
                      corCheck: primary,
                      onTap: () =>
                          themeModeController.setMode(ThemeMode.system),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Uma fila: texto + visto se for a opção activa (sem [RadioListTile] depreciado no SDK actual).
class _TemaOpTile extends StatelessWidget {
  const _TemaOpTile({
    required this.titulo,
    required this.selecionado,
    required this.corCheck,
    required this.onTap,
  });

  final String titulo;
  final bool selecionado;
  final Color corCheck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      title: Text(
        titulo,
        style: TextStyle(
          fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
          color: onSurface,
        ),
      ),
      trailing: selecionado
          ? Icon(Icons.check_rounded, color: corCheck)
          : const SizedBox(width: 24),
      onTap: onTap,
    );
  }
}
