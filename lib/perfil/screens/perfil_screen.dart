// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Tela **Perfil** (Figma): logo, título, cartão com avatar, secção CONTA com
// linhas configuráveis, Sair. Os dados vêm de [FirebaseAuth] + opcionalmente
// Firestore `users/{uid}`. A barra inferior continua a ser a do
// [MesclaMainShell] — este widget é só o corpo do separador 4.

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/services/user_firestore_service.dart';
import '../../catalog/models/catalog_startup.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../../theme/theme_mode_controller.dart';
import '../services/profile_photo_storage_service.dart';
import 'ajuda_suporte_screen.dart';
import 'favoritos_screen.dart';
import 'modo_aparencia_screen.dart';
import 'seguranca_privacidade_screen.dart';
import 'package:image_picker/image_picker.dart';

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
  /// Ficheiro escolhido na câmara/galeria — mostramos na hora, antes do upload terminar.
  File? _imagemAvatar;

  /// URL HTTPS gravada no Firestore (download URL do Firebase Storage).
  String? _urlFotoPerfil;

  /// `true` enquanto enviamos ou removemos foto (bloqueia ações duplicadas).
  bool _enviandoFoto = false;

  final ImagePicker _picker = ImagePicker();

  /// Uma instância por ecrã: evita relançar o [Future] a cada [build].
  late final Future<_PerfilDados> _carga = _carregarPerfil();

  @override
  void initState() {
    super.initState();
    // Ao abrir o perfil, buscamos a foto já salva (se existir).
    _carregarUrlFotoSalva();
  }

  /// Lê `users/{uid}.photoUrl` no Firestore e atualiza o avatar na tela.
  Future<void> _carregarUrlFotoSalva() async {
    String? url;
    try {
      url = await UserFirestoreService.fetchProfilePhotoUrl();
    } catch (_) {
      url = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _urlFotoPerfil = url;
    });
  }

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

  /// Abre o bottom sheet com câmara, galeria ou remover foto.
  void _mostrarOpcoesAvatar() {
    if (_enviandoFoto) {
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Escolher foto do perfil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tirar foto'),
                onTap: () async {
                  Navigator.pop(context);
                  await _tirarFoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () async {
                  Navigator.pop(context);
                  await _escolherGaleria();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remover foto'),
                onTap: () {
                  Navigator.pop(context);
                  _removerFoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Abre a câmara, depois envia a imagem para o Storage.
  Future<void> _tirarFoto() async {
    final imagem = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (imagem == null) {
      return;
    }

    await _enviarFotoParaStorage(File(imagem.path));
  }

  /// Abre a galeria, depois envia a imagem para o Storage.
  Future<void> _escolherGaleria() async {
    final imagem = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (imagem == null) {
      return;
    }

    await _enviarFotoParaStorage(File(imagem.path));
  }

  /// Fluxo completo: preview local → upload Storage → salvar URL no Firestore.
  ///
  /// Caminho no Storage: `profilePhoto/users/{uid}/avatar.jpg`
  /// (a pasta é criada automaticamente no primeiro upload).
  Future<void> _enviarFotoParaStorage(File arquivo) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para alterar a foto.')),
      );
      return;
    }

    setState(() {
      _imagemAvatar = arquivo;
      _enviandoFoto = true;
    });

    try {
      // 1) Envia bytes para o Firebase Storage e recebe a URL de download.
      final url = await ProfilePhotoStorageService.enviarFoto(
        arquivoLocal: arquivo,
        uid: uid,
      );

      // 2) Grava a URL no documento `users/{uid}` (campo `photoUrl`).
      await UserFirestoreService.setProfilePhotoUrl(url);

      if (!mounted) {
        return;
      }

      setState(() {
        _urlFotoPerfil = url;
        _imagemAvatar = null;
        _enviandoFoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil atualizada.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _imagemAvatar = null;
        _enviandoFoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível enviar a foto. Tente novamente.'),
        ),
      );
    }
  }

  /// Remove foto do Storage, apaga `photoUrl` no Firestore e limpa a UI.
  Future<void> _removerFoto() async {
    final temFotoLocal = _imagemAvatar != null;
    final temFotoRemota =
        _urlFotoPerfil != null && _urlFotoPerfil!.trim().isNotEmpty;

    if (!temFotoLocal && !temFotoRemota) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não possui foto de perfil')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover foto'),
          content: const Text('Deseja realmente remover sua foto de perfil?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para alterar a foto.')),
      );
      return;
    }

    setState(() {
      _enviandoFoto = true;
    });

    try {
      // Apaga o ficheiro no Storage (ignora se já não existir).
      await ProfilePhotoStorageService.removerFoto(uid);

      // Remove o campo `photoUrl` do Firestore.
      await UserFirestoreService.removeProfilePhotoUrl();

      if (!mounted) {
        return;
      }

      setState(() {
        _imagemAvatar = null;
        _urlFotoPerfil = null;
        _enviandoFoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto removida com sucesso')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _enviandoFoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover a foto. Tente novamente.'),
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
                onAvatarTap: _mostrarOpcoesAvatar,
                imagemAvatar: _imagemAvatar,
                urlFotoRemota: _urlFotoPerfil,
                enviandoFoto: _enviandoFoto,
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
    required this.onAvatarTap,
    required this.imagemAvatar,
    required this.urlFotoRemota,
    required this.enviandoFoto,
  });

  final String iniciais;
  final String nome;
  final String email;
  final Color primary;
  final ThemeData theme;
  final Color cardColor;
  final VoidCallback onAvatarTap;
  final File? imagemAvatar;

  /// URL vinda do Firestore (foto já enviada ao Storage).
  final String? urlFotoRemota;

  /// Mostra um indicador de carregamento por cima do avatar.
  final bool enviandoFoto;

  /// Decide o que mostrar dentro do círculo do avatar.
  Widget _conteudoAvatar() {
    // Prioridade 1: preview local (foto acabada de escolher).
    if (imagemAvatar != null) {
      return ClipOval(
        child: Image.file(
          imagemAvatar!,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
        ),
      );
    }

    // Prioridade 2: foto remota salva no Storage (via URL no Firestore).
    final url = urlFotoRemota?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          // Se a URL falhar (rede, ficheiro apagado), voltamos às iniciais.
          errorBuilder: (context, error, stackTrace) => Text(
            iniciais,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // Prioridade 3: sem foto — mostra iniciais do nome.
    return Text(
      iniciais,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

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
            GestureDetector(
              onTap: enviandoFoto ? null : onAvatarTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    child: _conteudoAvatar(),
                  ),
                  if (enviandoFoto)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
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
