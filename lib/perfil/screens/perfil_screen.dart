// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela **Perfil** (Figma): logo, título, cartão com avatar, secção CONTA com
// linhas configuráveis, Sair. Os dados vêm de [FirebaseAuth] + opcionalmente
// Firestore `users/{uid}`. A barra inferior continua a ser a do
// [MesclaMainShell] — este widget é só o corpo do separador 4.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/services/user_firestore_service.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../../theme/theme_mode_controller.dart';
import 'ajuda_suporte_screen.dart';
import 'favoritos_screen.dart';
import 'modo_aparencia_screen.dart';
import 'seguranca_privacidade_screen.dart';

/// Dados de exibição depois de resolver nome (Auth / Firestore / fallback).
class _PerfilDados {
  const _PerfilDados({
    required this.nomeExibicao,
    required this.email,
    required this.iniciais,
  });

  final String nomeExibicao;
  final String email;
  final String iniciais;
}

/// Gera 2 letras: duas palavras → iniciais; e-mail local → 1 letra; senão prefixo.
String _iniciaisDeNomeOuEmail(String origem) {
  final t = origem.trim();
  if (t.isEmpty) {
    return '?';
  }
  final partes = t
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList(growable: false);
  if (partes.length >= 2) {
    final a = partes[0][0];
    final b = partes[1][0];
    return ('$a$b').toUpperCase();
  }
  if (t.contains('@')) {
    final local = t.split('@').first;
    if (local.isEmpty) {
      return '?';
    }
    return local[0].toUpperCase();
  }
  if (t.length >= 2) {
    return t.substring(0, 2).toUpperCase();
  }
  return t[0].toUpperCase();
}

Future<_PerfilDados> _carregarPerfil() async {
  try {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      // Ex.: testes de widget sem sessão, ou sessão inválida.
      return const _PerfilDados(
        nomeExibicao: 'Utilizador',
        email: '—',
        iniciais: 'U',
      );
    }
    var nome = u.displayName?.trim();
    if (nome == null || nome.isEmpty) {
      nome = await UserFirestoreService.fetchNameFromFirestore(u.uid);
    }
    if (nome == null || nome.isEmpty) {
      nome = u.email?.split('@').first;
    }
    nome ??= 'Utilizador';
    final email = u.email ?? '—';
    return _PerfilDados(
      nomeExibicao: nome,
      email: email,
      iniciais: _iniciaisDeNomeOuEmail(nome),
    );
  } catch (_) {
    // [Firebase] não inicializado (ex. algum teste) ou outra falha: fallback seguro.
    return const _PerfilDados(
      nomeExibicao: 'Utilizador',
      email: '—',
      iniciais: 'U',
    );
  }
}

/// Ecrã do separador **Perfil** (avatar, CONTA, Sair, navegação para sub-rotas).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({
    super.key,
    this.wrapWithSafeArea = true,
    this.onInvestir,
    this.favoriteStartupIdsStream,
  });

  /// Quando o pai já aplicou [SafeArea] (ex.: [MesclaMainShell]), passa `false`.
  final bool wrapWithSafeArea;

  /// Repassado a [FavoritosScreen] — «Investir Agora» abre o Balcão (ex.: [DashboardScreen]).
  final void Function(CatalogStartup)? onInvestir;

  /// Permite injetar a lista de desejos em testes sem depender de Firebase.
  final Stream<List<String>>? favoriteStartupIdsStream;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  /// Uma instância por ecrã: evita relançar o [Future] a cada [build].
  late final Future<_PerfilDados> _carga = _carregarPerfil();

  static const _logoHeight = 52.0;
  static const _paddingH = 20.0;
  static const _cinzaConta = Color(0xFFF3F4F6);
  static const _corSairBorda = Color(0xFFEA580C);

  /// Material 3: [Dialog] com o mesmo desenho dos outros modais (cantos 24, ícone,
  /// textos com [AppColors], botões empilhados como em [AdicionarFundosScreen]).
  Future<void> _confirmarSair() async {
    final sair = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = theme.colorScheme.primary;
        final onPrimary = theme.colorScheme.onPrimary;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 40,
                  color: primary.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sair do aplicativo?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sua sessão será encerrada. Para acessar sua conta de '
                  'novo, você precisará fazer login.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(
                        color: primary.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                      backgroundColor: theme.colorScheme.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: onPrimary,
                      elevation: 2,
                      shadowColor: AppColors.primaryShadow(theme.colorScheme),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Sair'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (sair != true || !mounted) {
      return;
    }
    await _executarSair();
  }

  Future<void> _executarSair() async {
    try {
      await UserFirestoreService.signOut();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível sair da conta. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    // Bloco CONTA: cinza claro no light; no dark usamos o tom de superfície do Material 3.
    final fundoConta = theme.brightness == Brightness.light
        ? _cinzaConta
        : theme.colorScheme.surfaceContainerHighest;

    final conteudo = FutureBuilder<_PerfilDados>(
      future: _carga,
      builder: (context, snapshot) {
        final dados = snapshot.data;
        final nome = dados?.nomeExibicao ?? '…';
        final email = dados?.email ?? '…';
        final iniciais = dados?.iniciais ?? '…';

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(_paddingH, 8, _paddingH, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MesclaBrandLogo(boxHeight: _logoHeight, boxWidth: 200),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Perfil',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 20),
              _PerfilUserCard(
                iniciais: iniciais,
                nome: nome,
                email: email,
                primary: primary,
                theme: theme,
                cardColor: theme.colorScheme.surface,
              ),
              const SizedBox(height: 20),
              Text(
                'CONTA',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: fundoConta,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    StreamBuilder<List<String>>(
                      stream:
                          widget.favoriteStartupIdsStream ??
                          UserFirestoreService.watchFavoriteStartupIds(),
                      builder: (context, favSnap) {
                        final qtd = favSnap.data?.length ?? 0;
                        final subtitulo =
                            '$qtd ${qtd == 1 ? "startup" : "startups"} na lista de desejos';
                        return _PerfilConfigRow(
                          icon: Icons.favorite_border_rounded,
                          titulo: 'Lista de Desejos',
                          subtitulo: subtitulo,
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => FavoritosScreen(
                                  onInvestir: widget.onInvestir,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 72),
                    _PerfilConfigRow(
                      icon: Icons.shield_outlined,
                      titulo: 'Segurança e Privacidade',
                      subtitulo: '2FA, Senha',
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const SegurancaPrivacidadeScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 72),
                    ListenableBuilder(
                      listenable: themeModeController,
                      builder: (context, _) {
                        return _PerfilConfigRow(
                          icon: Icons.dark_mode_outlined,
                          titulo: 'Modo de Aparência',
                          subtitulo: mesclaThemeModeLabel(
                            themeModeController.themeMode,
                          ),
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => const ModoAparenciaScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 72),
                    _PerfilConfigRow(
                      icon: Icons.support_agent_outlined,
                      titulo: 'Ajuda e Suporte',
                      subtitulo: 'FAQ, contacto',
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const AjudaSuporteScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'SESSÃO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _confirmarSair,
                icon: const Icon(Icons.logout, color: _corSairBorda),
                label: const Text('Sair da Conta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _corSairBorda,
                  side: const BorderSide(color: _corSairBorda, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!widget.wrapWithSafeArea) {
      return conteudo;
    }
    return SafeArea(child: conteudo);
  }
}

// --- Cartão com avatar, nome, e-mail e chip INVESTIDOR ----------------------------

class _PerfilUserCard extends StatelessWidget {
  const _PerfilUserCard({
    required this.iniciais,
    required this.nome,
    required this.email,
    required this.primary,
    required this.theme,
    required this.cardColor,
  });

  final String iniciais;
  final String nome;
  final String email;
  final Color primary;
  final ThemeData theme;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(28),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
              child: Text(
                iniciais,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'INVESTIDOR',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Linha “ListTile” do bloco CONTA (ícone + textos + chevron) -------------------

class _PerfilConfigRow extends StatelessWidget {
  const _PerfilConfigRow({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icon;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconCircle = theme.brightness == Brightness.light
        ? const Color(0xFFE5E7EB)
        : theme.colorScheme.surfaceContainerHigh;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconCircle,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.textSecondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
