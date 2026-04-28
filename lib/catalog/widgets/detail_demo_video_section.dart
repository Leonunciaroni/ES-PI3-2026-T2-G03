// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Vídeo de demonstração embutido (YouTube) na ficha da startup — área compacta 16:9;
// o utilizador usa o botão play do próprio player. Outros URLs continuam a abrir fora.

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../theme/app_colors.dart';

/// Garante esquema para [Uri] / [launchUrl] (`youtu.be/...`, `www.youtube.com/...`).
String? videoUrlWithHttpsScheme(String? raw) {
  if (raw == null) {
    return null;
  }
  final String t = raw.trim();
  if (t.isEmpty) {
    return null;
  }
  if (t.contains('://')) {
    return t;
  }
  return 'https://$t';
}

/// Extrai o ID de 11 caracteres a partir de links comuns do YouTube.
String? youtubeVideoIdFromUrl(String? raw) {
  final String? url = videoUrlWithHttpsScheme(raw);
  if (url == null) {
    return null;
  }
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }
  final String host = uri.host.toLowerCase();
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    if (uri.pathSegments.isEmpty) {
      return null;
    }
    return uri.pathSegments.first;
  }
  if (host.contains('youtube.com')) {
    final String? v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) {
      return v;
    }
    final List<String> segs = uri.pathSegments;
    if (segs.length >= 2) {
      final String kind = segs[0];
      if (kind == 'embed' || kind == 'shorts' || kind == 'live') {
        return segs[1];
      }
    }
  }
  return null;
}

/// Secção de vídeo: player miniatura para YouTube; [ListTile] para resto / sem URL.
class DetailDemoVideoSection extends StatefulWidget {
  const DetailDemoVideoSection({
    super.key,
    required this.videoTitle,
    required this.videoUrl,
    required this.primary,
    required this.onOpenExternal,
  });

  final String videoTitle;
  final String? videoUrl;
  final Color primary;
  final Future<void> Function(String? url) onOpenExternal;

  @override
  State<DetailDemoVideoSection> createState() => _DetailDemoVideoSectionState();
}

class _DetailDemoVideoSectionState extends State<DetailDemoVideoSection> {
  YoutubePlayerController? _controller;
  int _attachGeneration = 0;

  @override
  void initState() {
    super.initState();
    _schedulePlayerAttach(widget.videoUrl);
  }

  @override
  void didUpdateWidget(covariant DetailDemoVideoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl == widget.videoUrl) {
      return;
    }
    // URL mudou (ex.: [startupDetailFor] → Firestore): invalida attach antigo.
    _controller?.dispose();
    _controller = null;
    _schedulePlayerAttach(widget.videoUrl);
  }

  /// Cria o [YoutubePlayerController] *depois* do 1.º frame para não bloquear a
  /// transição de rota nem o [StreamBuilder] (WebView é pesado na UI thread).
  void _schedulePlayerAttach(String? videoUrl) {
    final String? id = youtubeVideoIdFromUrl(videoUrl);
    if (id == null || id.length != 11) {
      return;
    }
    final int gen = ++_attachGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || gen != _attachGeneration) {
        return;
      }
      if (youtubeVideoIdFromUrl(widget.videoUrl) != id) {
        return;
      }
      // Cede à animação; evita pico de trabalho no mesmo tique que a lista.
      Future<void>.delayed(Duration.zero, () {
        if (!mounted || gen != _attachGeneration) {
          return;
        }
        if (youtubeVideoIdFromUrl(widget.videoUrl) != id) {
          return;
        }
        _controller?.dispose();
        _controller = YoutubePlayerController(
          initialVideoId: id,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            controlsVisibleAtStart: false,
            enableCaption: true,
          ),
        );
        setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _attachGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  Widget _openExternalButton(ThemeData theme) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => widget.onOpenExternal(widget.videoUrl),
        icon: Icon(
          Icons.open_in_new_rounded,
          size: 20,
          color: widget.primary,
        ),
        label: Text(
          'Abrir no app YouTube / navegador',
          style: theme.textTheme.labelLarge?.copyWith(
            color: widget.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.primary,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: widget.primary.withValues(alpha: 0.45),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? url = widget.videoUrl?.trim();

    if (url == null || url.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.play_circle_outline_rounded,
          color: widget.primary,
          size: 40,
        ),
        title: Text(widget.videoTitle),
        subtitle: const Text('Protótipo — reprodução simulada'),
        onTap: () => widget.onOpenExternal(null),
      );
    }

    final String? youTubeId = youtubeVideoIdFromUrl(url);
    if (youTubeId != null && youTubeId.length == 11) {
      if (_controller != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.videoTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Toque em play no vídeo para assistir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: YoutubePlayer(
                  key: ObjectKey(_controller),
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                  aspectRatio: 16 / 9,
                  progressIndicatorColor: widget.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _openExternalButton(theme),
          ],
        );
      }
      // URL válido, leitor a carregar (não mostrar o ListTile a errar "não YouTube").
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.videoTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Preparando o leitor de vídeo…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: const Color(0xFF0F0F0F).withValues(alpha: 0.08),
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _openExternalButton(theme),
        ],
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.play_circle_outline_rounded,
        color: widget.primary,
        size: 40,
      ),
      title: Text(widget.videoTitle),
      subtitle: const Text('Link não é do YouTube — abre fora do app'),
      onTap: () => widget.onOpenExternal(widget.videoUrl),
    );
  }
}
