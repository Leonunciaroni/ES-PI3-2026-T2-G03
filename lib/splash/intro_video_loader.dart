import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Pré-carrega o vídeo de intro antes do primeiro frame para reduzir tela preta.
class IntroVideoLoader {
  IntroVideoLoader._();

  static const String assetPath = 'assets/videos/intro.mp4';

  static VideoPlayerController? _controller;
  static Future<VideoPlayerController?>? _prepareFuture;

  /// Controller já inicializado, ou `null` se falhou.
  static VideoPlayerController? get preparedController => _controller;

  /// Inicia decode do asset; seguro chamar mais de uma vez.
  static Future<VideoPlayerController?> prepare() {
    _prepareFuture ??= _prepare();
    return _prepareFuture!;
  }

  static Future<VideoPlayerController?> _prepare() async {
    final VideoPlayerController controller =
        VideoPlayerController.asset(assetPath);
    try {
      await controller.initialize();
      await controller.setVolume(0);
      _controller = controller;
      return controller;
    } catch (e, stack) {
      _prepareFuture = null;
      if (kDebugMode) {
        debugPrint('IntroVideoLoader: falha ao carregar $assetPath: $e');
        debugPrintStack(stackTrace: stack);
      }
      await controller.dispose();
      return null;
    }
  }

  /// Libera recursos se o splash não for exibido (ex.: testes com outro home).
  static Future<void> disposePrepared() async {
    final VideoPlayerController? controller = _controller;
    _controller = null;
    _prepareFuture = null;
    if (controller != null) {
      await controller.dispose();
    }
  }
}
