import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../auth/screens/auth_gate_screen.dart';
import '../intro_video_loader.dart';

/// Splash com vídeo de introdução da marca (asset pré-carregado em [IntroVideoLoader]).
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.initialController,
    this.skipVideo = false,
  });

  /// Controller já inicializado (ex.: testes); senão usa [IntroVideoLoader].
  final VideoPlayerController? initialController;

  /// Pula o vídeo imediatamente (widget tests, onde o player não está disponível).
  final bool skipVideo;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipVideo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
      return;
    }
    _startPlayback();
  }

  Future<void> _startPlayback() async {
    if (widget.skipVideo) {
      return;
    }
    VideoPlayerController? controller =
        widget.initialController ?? IntroVideoLoader.preparedController;

    if (controller == null || !controller.value.isInitialized) {
      controller = await IntroVideoLoader.prepare();
    }

    if (!mounted) {
      return;
    }

    if (controller == null || !controller.value.isInitialized) {
      _goNext();
      return;
    }

    _controller = controller;

    try {
      controller
        ..setLooping(false)
        ..addListener(_onVideoProgress);

      setState(() {});
      await controller.play();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('SplashScreen: falha ao reproduzir intro: $e');
        debugPrintStack(stackTrace: stack);
      }
      _goNext();
    }
  }

  void _onVideoProgress() {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.hasError) {
      if (kDebugMode) {
        debugPrint(
          'SplashScreen: erro no player: ${controller.value.errorDescription}',
        );
      }
      _goNext();
      return;
    }

    if (controller.value.isCompleted) {
      _goNext();
    }
  }

  void _goNext() {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;
    _controller?.removeListener(_onVideoProgress);
    if (widget.initialController == null) {
      IntroVideoLoader.disposePrepared();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const AuthGateScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    final bool ready =
        controller != null && controller.value.isInitialized;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Semantics(
          label: 'Introdução da marca. Toque para pular.',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _goNext,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (ready)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
