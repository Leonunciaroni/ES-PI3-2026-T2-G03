// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Logo da startup a partir de [logoPath]: caminho no Firebase Storage ou URL https.
//
// [_logoUrlCache] é um mapa global path → Future<String>: o download URL é
// resolvido uma única vez por sessão e reutilizado em todos os widgets/telas.
//
// Todas as instâncias de [StartupLogoAvatar] na app decodificam o bitmap pelo mesmo
// [ResizeImage] (área física proporcional a [kStartupLogoRasterLogicalSidePx] × DPR)
// para que o [precacheImage] do [preloadStartupLogoBitmaps] use a mesma chave na
// [ImageCache] — assim o pré-carregar de verdade aparece já no card sem novo download.

import 'dart:async' show unawaited;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ── Cache global ────────────────────────────────────────────────────────────
/// Indexed by raw logoPath trim. Shared across all widget instances and routes.
final Map<String, Future<String>> _logoUrlCache = {};

/// URLs já resolvidas (Storage → HTTPS). Primeira renderização após resolver:
/// o [StartupLogoAvatar] mostra foto sem voltar ao estado “à espera” do futuro só
/// para obter URL (persiste até hot restart/logout libertar estado estático externo).
final Map<String, String> _resolvedUrlStringCache = {};

/// Maior lado lógico de logo na app (lista 48, mesa 52 → usamos 64 px lógicos
/// antes do DPR) para todas as vistas partilharem **uma** entrada decodificada.
///
/// Mudar apenas se aumentar bastante o tamanho dos avatars em todas as telas.
const double kStartupLogoRasterLogicalSidePx = 64;

/// Janelas de rede em paralelo no [preloadStartupLogoBitmaps] ([precacheImage]) —
/// maior = mais rápido no total, mais uso de rede e RAM de curto prazo.
const int kStartupLogoPrecacheConcurrency = 5;

int _decodedPixelSideForLogo(BuildContext context) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (kStartupLogoRasterLogicalSidePx * dpr).round().clamp(1, 8192);
}

/// Lado físico único dos bitmaps pré-carregados e exibidos (alinhado ao [preloadStartupLogoBitmaps]).
int startupLogoDecodedPixelSide(BuildContext context) => _decodedPixelSideForLogo(context);

/// Pré-aquece o futuro Storage→URL para uma lista de caminhos.
/// Chame logo após receber a lista de startups do Firestore.
void prewarmLogoUrlCache(Iterable<String?> paths) {
  for (final p in paths) {
    if (p != null && p.trim().isNotEmpty) {
      unawaited(_memoDownloadUrl(p.trim()));
    }
  }
}

Future<String> _memoDownloadUrl(String trimmed) {
  final sync = _resolvedUrlStringCache[trimmed];
  if (sync != null) return Future<String>.value(sync);
  return _logoUrlCache.putIfAbsent(trimmed, () async {
    final url = await _resolveStorageUrl(trimmed);
    _resolvedUrlStringCache[trimmed] = url;
    return url;
  });
}

/// Descarrega logos para [ImageCache] usando o **mesmo** [ResizeImage] que [StartupLogoAvatar] —
/// assim `[Image]` lê sempre a entrada criada pelo preload em vez de refazer redes parcialmente diferentes.
///
/// Corre em paralelo por blocos para não ficar sempre sequencial atrás das primeiras
/// startups enquanto o utilizador já está na lista.
///
/// Deve usar [context] com [MediaQuery] ([mounted] válido antes e entre lotes).
Future<void> preloadStartupLogoBitmaps(
  BuildContext context,
  Iterable<String?> paths,
) async {
  prewarmLogoUrlCache(paths);
  final uniq = <String>{};
  for (final raw in paths) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) continue;
    uniq.add(t);
  }
  if (uniq.isEmpty) return;
  final decodedSide = startupLogoDecodedPixelSide(context);

  Future<void> one(String trimmed) async {
    try {
      final url = await _memoDownloadUrl(trimmed);
      if (!context.mounted) return;
      await precacheImage(
        ResizeImage(
          NetworkImage(url),
          width: decodedSide,
          height: decodedSide,
        ),
        context,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('preloadStartupLogoBitmaps($trimmed): $e');
      }
    }
  }

  final list = uniq.toList();
  for (var i = 0; i < list.length; i += kStartupLogoPrecacheConcurrency) {
    if (!context.mounted) return;
    final end = (i + kStartupLogoPrecacheConcurrency < list.length)
        ? i + kStartupLogoPrecacheConcurrency
        : list.length;
    final chunk = list.sublist(i, end);
    await Future.wait<void>(chunk.map(one));
  }
}

// ── Resolução de URL ────────────────────────────────────────────────────────
FirebaseStorage _storage() {
  try {
    final app = Firebase.app();
    final raw = app.options.storageBucket;
    if (raw == null || raw.isEmpty) return FirebaseStorage.instance;
    final bucket = raw.startsWith('gs://') ? raw : 'gs://$raw';
    return FirebaseStorage.instanceFor(app: app, bucket: bucket);
  } catch (_) {
    return FirebaseStorage.instance;
  }
}

Future<String> _resolveStorageUrl(String p) async {
  if (p.isEmpty) throw StateError('empty logoPath');

  if (p.startsWith('http://') || p.startsWith('https://')) {
    final lower = p.toLowerCase();
    final isStorage = lower.contains('firebasestorage.googleapis.com') ||
        lower.contains('firebasestorage.app');
    if (isStorage) {
      try {
        return await _storage().refFromURL(p).getDownloadURL();
      } catch (e) {
        if (kDebugMode) debugPrint('StartupLogoAvatar refFromURL warn: $e');
        return p;
      }
    }
    return p;
  }

  if (p.startsWith('gs://')) {
    return _storage().refFromURL(p).getDownloadURL();
  }

  final relative = p.startsWith('/') ? p.substring(1) : p;
  return _storage().ref(relative).getDownloadURL();
}

// ── Widget ───────────────────────────────────────────────────────────────────

/// Avatar quadrado com imagem do Storage / rede, ou ícone de setor como fallback.
///
/// Primeiro resolve URL (cache sessão); decodifica com [ResizeImage] alinhado ao preload.
/// Navegar para outra tela e voltar deve mostrar o logo assim que já estiver em cache de imagem.
class StartupLogoAvatar extends StatelessWidget {
  const StartupLogoAvatar({
    super.key,
    required this.logoPath,
    required this.fallbackColor,
    required this.fallbackIcon,
    this.size = 48,
    this.borderRadius = 12,
  });

  /// Caminho no bucket (ex.: `logos/startups/foo.png`) ou URL `https://...`.
  final String? logoPath;

  final Color fallbackColor;
  final IconData fallbackIcon;
  final double size;
  final double borderRadius;

  Widget _decodedImage(BuildContext context, String downloadUrl) {
    final decoded = startupLogoDecodedPixelSide(context);
    return Image(
      image: ResizeImage(
        NetworkImage(downloadUrl),
        width: decoded,
        height: decoded,
      ),
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Future<String> _future() {
    final p = logoPath!.trim();
    return _memoDownloadUrl(p);
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = logoPath?.trim();
    if (trimmed == null || trimmed.isEmpty) return _fallback();

    /// Caminho rápido: URL já ficou disponível antes (preload ou uso anterior na sessão).
    final sync = _resolvedUrlStringCache[trimmed];
    if (sync != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _decodedImage(context, sync),
      );
    }

    return FutureBuilder<String>(
      future: _future(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: _decodedImage(context, snapshot.data!),
          );
        }
        if (snapshot.hasError) {
          if (kDebugMode) debugPrint('StartupLogoAvatar error: ${snapshot.error}');
          return _fallback();
        }
        return _fallback(
          child: SizedBox(
            width: size * 0.45,
            height: size * 0.45,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        );
      },
    );
  }

  Widget _fallback({Widget? child}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child ??
          Icon(fallbackIcon, color: Colors.white, size: size * 0.54),
    );
  }
}
