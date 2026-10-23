import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_controller.dart';
import '../widgets/attendance_summary_card.dart';
import '../widgets/holidays_card.dart';
import '../widgets/leave_summary_card.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/stats_row.dart';

class HomeDashboardView extends GetView<HomeController> {
  const HomeDashboardView({super.key});

  static const _horizontalPadding = EdgeInsets.symmetric(horizontal: 16);

  @override
  Widget build(BuildContext context) {
    final main = Get.find<MainController>();
    return Obx(
      () => Column(
        children: [
          const ProfileHeaderCard(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.brandBlue,
              backgroundColor: AppColors.white,
              onRefresh: controller.refreshDashboard,
              child: controller.isLoading.value &&
                      controller.employeeName.value.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandBlue,
                      ),
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 20, bottom: 28),
                      children: [
                        ResponsiveBody(
                          child: Padding(
                          padding: _horizontalPadding,
                          child: Column(
                            children: [
                              if (controller.loadError.value.isNotEmpty) ...[
                                _LoadErrorCard(
                                  message: controller.loadError.value,
                                  onRetry: controller.refreshDashboard,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (main.canUse('attendance')) ...[
                                const AttendanceSummaryCard(),
                                const SizedBox(height: 16),
                              ],
                              // Approval/activity counters are a full-user view.
                              if (!main.isEmployeeMode) ...[
                                const StatsRow(),
                                const SizedBox(height: 12),
                              ],
                              const QuickActionsRow(),
                              const SizedBox(height: 12),
                              if (main.canUse('leave')) ...[
                                const LeaveSummaryCard(),
                                const SizedBox(height: 16),
                              ],
                              const HolidaysCard(),
                              const SizedBox(height: 8),
                              const _FooterNote(),
                            ],
                          ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Explains an empty dashboard instead of leaving the user guessing.
class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Couldn't load your data",
                  style: AppTextStyles.style(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTextStyles.style(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: AppTextStyles.style(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Pull down to refresh your dashboard',
        style: AppTextStyles.style(
          fontSize: 12,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
