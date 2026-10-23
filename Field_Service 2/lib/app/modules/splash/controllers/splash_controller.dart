import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../routes/app_routes.dart';

/// Routes after splash. Navigation is triggered by [SplashView] when the splash
/// video finishes (or on timeout / error) — not a fixed timer, so MP4 is not cut short.
class SplashController extends GetxController {
  bool _hasNavigated = false;

  /// Call once when splash should end (video completed, or fallback).
  void navigateFromSplash() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    final box = GetStorage();
    final isLoggedIn = box.read<bool>('is_logged_in') ?? false;
    if (isLoggedIn) {
      Get.offAllNamed(AppRoutes.dashboard);
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }
}
