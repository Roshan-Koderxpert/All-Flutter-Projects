import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_controller.dart';
import 'dashboard_card.dart';

class LeaveSummaryCard extends GetView<HomeController> {
  const LeaveSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => DashboardCard(
        onTap: () => Get.find<MainController>().changeTab(2),
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
                    Icons.note_alt_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Leave Balance',
                    style: AppTextStyles.style(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF454545),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all',
                        style: AppTextStyles.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandOrange,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.brandOrange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.leaveBalances.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No leave data available',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.style(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...controller.leaveBalances.take(3).map(
                    (item) {
                      final progress = item.total > 0
                          ? (item.remaining / item.total).clamp(0.0, 1.0)
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: AppTextStyles.style(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF454545),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.remaining.toStringAsFixed(1)} / ${item.total.toStringAsFixed(1)}',
                                  style: AppTextStyles.style(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF454545),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor:
                                    AppColors.brandBlue.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress > 0.3
                                      ? AppColors.brandBlue
                                      : AppColors.brandOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
