import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/home_controller.dart';

class ProfileHeaderCard extends GetView<HomeController> {
  const ProfileHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final topPadding = MediaQuery.of(context).padding.top;

    return Obx(
      () {
        final avatar = controller.profileAvatarBase64;
        return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.brandBlue,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        // The navy band stays full-bleed; only what sits on it is capped. The
        // cap wraps the padding (not the other way round) so the header lines
        // up with the dashboard cards below at exactly the phone's offsets.
        child: ResponsiveBody(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 28),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: AppTextStyles.style(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formattedDate(),
                        style: AppTextStyles.style(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const NotificationBell(),
                const SizedBox(width: 4),
                _ProfileButton(imageBase64: avatar),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Avatar(imageBase64: avatar),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.greeting,
                        style: AppTextStyles.style(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.displayName,
                        style: AppTextStyles.style(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (controller.jobTitle.value.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            controller.jobTitle.value,
                            style: AppTextStyles.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (auth.selectedCompanyNames.value.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                auth.selectedCompanyNames.value,
                                style: AppTextStyles.style(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
        ),
        );
      },
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({this.imageBase64});

  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () => Get.toNamed(AppRoutes.profile),
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: _AvatarSmall(imageBase64: imageBase64),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.imageBase64});

  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildImage(radius: 34, iconSize: 36),
    );
  }

  Widget _buildImage({required double radius, required double iconSize}) {
    final safe = OdooImage.sanitize(imageBase64);
    if (safe != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: MemoryImage(base64Decode(safe)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Icon(Icons.person, size: iconSize, color: AppColors.brandBlue),
    );
  }
}

class _AvatarSmall extends StatelessWidget {
  const _AvatarSmall({this.imageBase64});

  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    final safe = OdooImage.sanitize(imageBase64);
    if (safe != null) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        backgroundImage: MemoryImage(base64Decode(safe)),
      );
    }
    return const CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white,
      child: Icon(Icons.person, size: 20, color: AppColors.brandBlue),
    );
  }
}
