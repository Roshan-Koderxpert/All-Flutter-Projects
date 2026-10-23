import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_datetime.dart';
import '../../../core/widgets/asset_icon.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_controller.dart';
import 'dashboard_card.dart';

const _red = Color(0xFFDB3F3F);
const _green = Color(0xFF3DA93D);

class AttendanceSummaryCard extends GetView<HomeController> {
  const AttendanceSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => DashboardCard(
        accentColor: AppColors.brandBlue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.access_time_filled,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Today's Attendance",
                    style: AppTextStyles.style(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _StatusChip(status: controller.attendanceStatus.value),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _TimeBlock(
                    label: 'Check In',
                    time: controller.formatTime(controller.checkInTime.value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeBlock(
                    label: 'Check Out',
                    time: controller.formatTime(controller.checkOutTime.value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeBlock(
                    label: 'Hours',
                    time: OdooDateTime.formatHours(
                      controller.workedHoursToday.value,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => _GradientButton(
                      onPressed: controller.isBusyWithAttendance ||
                              !controller.canCheckIn
                          ? null
                          : controller.checkIn,
                      isLoading: controller.isCheckingIn.value,
                      assetPath: AppIcon.checkIn,
                      fallbackIcon: Icons.login_rounded,
                      label: 'Check In',
                      gradient: const LinearGradient(
                        colors: [_green, _green],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(
                    () => _GradientButton(
                      onPressed: controller.isBusyWithAttendance ||
                              !controller.canCheckOut
                          ? null
                          : controller.checkOut,
                      isLoading: controller.isCheckingOut.value,
                      assetPath: AppIcon.checkOut,
                      fallbackIcon: Icons.logout_rounded,
                      label: 'Check Out',
                      gradient: const LinearGradient(
                        colors: [_red, _red],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Obx(
              () => controller.isRouteTracking.value
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Route tracking active',
                            style: AppTextStyles.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => Get.find<MainController>().changeTab(1),
                icon: const AssetIcon(
                  assetPath: AppIcon.viewHistory,
                  fallback: Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.brandBlue,
                ),
                label: const Text('View attendance history'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.isLoading,
    required this.assetPath,
    required this.fallbackIcon,
    required this.label,
    required this.gradient,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String assetPath;
  final IconData fallbackIcon;
  final String label;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: disabled ? null : gradient,
            color: disabled ? AppColors.border : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  AssetIcon(
                    assetPath: assetPath,
                    fallback: fallbackIcon,
                    size: 18,
                    color: disabled ? AppColors.textSecondary : Colors.white,
                  ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.style(
                    fontWeight: FontWeight.w700,
                    color: disabled ? AppColors.textSecondary : Colors.white,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;

    switch (status) {
      case 'checked_in':
        label = 'On Duty';
        bg = AppColors.brandBlue;
      case 'checked_out':
        label = 'Checked Out';
        bg = _green;
      default:
        label = 'Absent';
        bg = _red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.style(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.label,
    required this.time,
  });

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.style(
              fontSize: 12,
              color: AppColors.brandBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: AppTextStyles.style(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }
}
