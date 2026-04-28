// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Logo da startup a partir de [logoPath]: caminho no Firebase Storage ou URL https.
//
// [_logoUrlCache] é um mapa global path → Future<String>: o download URL é
// resolvido uma única vez por sessão e reutilizado em todos os widgets/telas.
// Isso evita o spinner ao navegar para Balcão, Detalhes, etc.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ── Cache global ────────────────────────────────────────────────────────────
// Indexed by raw logoPath. Shared across all widget instances and routes.
final Map<String, Future<String>> _logoUrlCache = {};

/// Pré-aquece o cache para uma lista de caminhos.
/// Chame logo após receber a lista de startups do Firestore.
void prewarmLogoUrlCache(Iterable<String?> paths) {
  for (final p in paths) {
    if (p != null && p.trim().isNotEmpty) {
      _logoUrlCache.putIfAbsent(p.trim(), () => _resolveStorageUrl(p.trim()));
    }
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
/// O download URL é resolvido uma única vez por sessão ([_logoUrlCache]).
/// Navegar para outra tela e voltar mostra o logo instantaneamente.
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

  Future<String> _future() {
    final p = logoPath!.trim();
    return _logoUrlCache.putIfAbsent(p, () => _resolveStorageUrl(p));
  }

  @override
  Widget build(BuildContext context) {
    final p = logoPath?.trim();
    if (p == null || p.isEmpty) return _fallback();

    return FutureBuilder<String>(
      future: _future(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.network(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
            ),
          );
        }
        if (snapshot.hasError) {
          if (kDebugMode) debugPrint('StartupLogoAvatar error: ${snapshot.error}');
          return _fallback();
        }
        // Ainda carregando: mostra spinner discreto dentro do fallback.
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
