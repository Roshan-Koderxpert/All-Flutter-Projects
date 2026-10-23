import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Consistent, floating, solid-fill snackbars matching the app's design
/// system (solid color + white text/icon, rounded corners, soft shadow).
class AppSnackbar {
  AppSnackbar._();

  static void success(String title, String message) => _show(
        title: title,
        message: message,
        color: const Color(0xFF3DA93D),
        icon: Icons.check_circle_rounded,
      );

  static void error(String title, String message) => _show(
        title: title,
        message: message,
        color: const Color(0xFFDB3F3F),
        icon: Icons.error_rounded,
      );

  static void warning(String title, String message) => _show(
        title: title,
        message: message,
        color: AppColors.brandOrange,
        icon: Icons.warning_rounded,
      );

  static void info(String title, String message) => _show(
        title: title,
        message: message,
        color: AppColors.brandBlue,
        icon: Icons.info_rounded,
      );

  static void _show({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    Get.snackbar(
      title,
      message,
      titleText: Text(
        title,
        style: AppTextStyles.style(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      messageText: Text(
        message,
        style: AppTextStyles.style(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 13,
          height: 1.3,
        ),
      ),
      icon: Icon(icon, color: Colors.white, size: 26),
      backgroundColor: color,
      snackPosition: SnackPosition.BOTTOM,
      snackStyle: SnackStyle.FLOATING,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 14,
      duration: const Duration(seconds: 3),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
