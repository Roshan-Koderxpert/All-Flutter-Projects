import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../controllers/splash_controller.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  static const String _videoAsset = 'assets/animations/logo_2.mp4';

  /// Safety cap so the app never hangs if the video never reports completion.
  static const Duration _maxSplashDuration = Duration(seconds: 30);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  VideoPlayerController? _videoController;
  bool _initFailed = false;
  Timer? _maxWaitTimer;

  SplashController get _splash => Get.find<SplashController>();

  @override
  void initState() {
    super.initState();
    _splash; // ensure registered
    _maxWaitTimer = Timer(SplashView._maxSplashDuration, () {
      if (mounted) _splash.navigateFromSplash();
    });
    _initVideo();
  }

  void _onVideoTick() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;

    final d = c.value.duration;
    final p = c.value.position;
    if (d == Duration.zero) return;

    // End of non-looping clip (small margin for decoder rounding).
    if (p >= d - const Duration(milliseconds: 200)) {
      c.removeListener(_onVideoTick);
      _splash.navigateFromSplash();
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(SplashView._videoAsset);
    _videoController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      // Play once through — looping + fixed timer was cutting the clip mid-play.
      await controller.setLooping(false);
      await controller.setVolume(0);
      controller.addListener(_onVideoTick);
      await controller.play();

      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() => _initFailed = true);
      // No video: still go to app after a short beat.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) _splash.navigateFromSplash();
    }
  }

  @override
  void dispose() {
    _maxWaitTimer?.cancel();
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _videoController;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: _initFailed
            ? const Center(
                child: Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
              )
            : c != null && c.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: c.value.size.width,
                      height: c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}
