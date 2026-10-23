import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../core/assets/app_assets.dart';

/// Plays the brand splash video once, then hands off to [nextRoute].
///
/// Shown as the app's `home` (not a named route) so it can run before any
/// auth-gated navigation — [nextRoute] is whichever screen `main()` already
/// decided on (login, biometric lock, or home) based on the saved session.
class SplashView extends StatefulWidget {
  const SplashView({super.key, required this.nextRoute});

  final String nextRoute;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  VideoPlayerController? _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Deliberately no SystemChrome call here: the Scaffold body already spans
    // the full screen (including behind the status bar), and asking Android
    // for an immersive mode makes it pop its own "Viewing full screen" notice
    // over the splash.

    // Safety net: always move on even if the video fails to load or play.
    Future.delayed(const Duration(seconds: 8), _goNext);

    final controller = VideoPlayerController.asset(AppAnimation.splash);
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          controller
            ..setLooping(false)
            ..play();
        })
        .catchError((_) {
          _goNext();
        });
    controller.addListener(_checkVideoEnd);
  }

  void _checkVideoEnd() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    if (value.duration > Duration.zero && value.position >= value.duration) {
      _goNext();
    }
  }

  void _goNext() {
    if (_navigated) return;
    _navigated = true;
    Get.offAllNamed(widget.nextRoute);
  }

  @override
  void dispose() {
    _controller?.removeListener(_checkVideoEnd);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final size = ready ? controller.value.size : Size.zero;

    // The video is 9:16 but phones/tablets are taller or wider, so scale it to
    // cover the screen and crop the overflow — no letterbox bars of any colour.
    return Scaffold(
      backgroundColor: AppAnimation.splashBackground,
      body: SizedBox.expand(
        child: ready
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(controller),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
