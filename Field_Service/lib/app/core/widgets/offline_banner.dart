import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../services/connectivity_service.dart';
import '../theme/text_styles.dart';

/// Thin global strip when the device has no network route.
/// Does not block interaction — only informs the user (offline-first UX).
class OfflineBannerHost extends StatelessWidget {
  const OfflineBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Obx(() {
          if (!Get.isRegistered<ConnectivityService>()) {
            return const SizedBox.shrink();
          }
          if (Get.find<ConnectivityService>().isOnline.value) {
            return const SizedBox.shrink();
          }
          return const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _OfflineBanner(),
          );
        }),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFF6B6B),
      elevation: 3,
      shadowColor: Colors.black26,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Offline Mode – Changes will sync when back online',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}