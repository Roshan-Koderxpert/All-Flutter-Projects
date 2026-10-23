import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../modules/auth/controllers/auth_controller.dart';
import '../../modules/home/controllers/home_controller.dart';
import '../theme/app_colors.dart';
import '../utils/odoo_image.dart';

class AppBarProfileButton extends StatelessWidget {
  const AppBarProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Obx(
      () {
        String? imageBase64;
        if (Get.isRegistered<HomeController>()) {
          imageBase64 = Get.find<HomeController>().profileAvatarBase64;
        } else {
          imageBase64 = OdooImage.sanitize(auth.activeAccount.value?.image1920);
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Get.toNamed(AppRoutes.profile),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _buildAvatar(imageBase64),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String? imageBase64) {
    final safe = OdooImage.sanitize(imageBase64);
    if (safe == null) return _defaultAvatar();

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: MemoryImage(base64Decode(safe)),
    );
  }

  Widget _defaultAvatar() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: const Icon(
        Icons.person,
        size: 22,
        color: AppColors.primary,
      ),
    );
  }
}
