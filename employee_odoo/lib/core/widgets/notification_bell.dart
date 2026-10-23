import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../modules/notifications/controllers/notification_controller.dart';
import '../assets/app_assets.dart';
import 'asset_icon.dart';
import 'notification_sheet.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();
    return Obx(() => Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const AssetIcon(
            assetPath: AppIcon.notification,
            fallback: Icons.notifications_outlined,
            size: 24,
            color: Colors.white,
          ),
          onPressed: () => showNotificationSheet(context),
        ),
        if (controller.unreadCount.value > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                controller.unreadCount.value > 9 ? '9+' : '${controller.unreadCount.value}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ));
  }
}