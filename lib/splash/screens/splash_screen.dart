import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../auth/screens/auth_gate_screen.dart';
import '../../theme/app_colors.dart';

/// Splash animada com o vídeo de introdução da marca.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String introVideoAsset = 'assets/videos/intro.mp4';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final VideoPlayerController controller =
        VideoPlayerController.asset(SplashScreen.introVideoAsset);
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) {
        return;
      }

      controller
        ..setLooping(false)
        ..addListener(_onVideoProgress);

      setState(() {});
      await controller.play();
    } catch (_) {
      _goNext();
    }
  }

  void _onVideoProgress() {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final Duration position = controller.value.position;
    final Duration duration = controller.value.duration;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 200)) {
      _goNext();
    }
  }

  void _goNext() {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;
    _controller?.removeListener(_onVideoProgress);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const AuthGateScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
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
        body: GestureDetector(
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
                )
              else
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.seedPurple,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
