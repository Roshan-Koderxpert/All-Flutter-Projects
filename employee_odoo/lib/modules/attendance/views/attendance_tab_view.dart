import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../home/widgets/section_title.dart';
import '../controllers/attendance_controller.dart';
import '../widgets/attendance_odoo_list.dart';
import '../widgets/attendance_odoo_search_bar.dart';
import '../widgets/attendance_today_card.dart';

class AttendanceTabView extends GetView<AttendanceController> {
  const AttendanceTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AttendanceTodayCard(),
              const SizedBox(height: 16),
              const SectionTitle(
                title: 'Attendance History',
                subtitle: 'Grouped by month and employee',
                accentColor: AppColors.brandOrange,
              ),
              // Says so when the record cap hides older months, rather than
              // letting the list just stop.
              Obx(() {
                if (!controller.isHistoryTruncated.value) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.brandOrange.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Showing the most recent records — older attendance '
                          'is not loaded. Use the date filter to see it.',
                          style: AppTextStyles.style(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const AttendanceOdooSearchBar(),
        Expanded(child: _buildHistoryBody()),
      ],
      ),
    );
  }

  Widget _buildHistoryBody() {
    return Obx(
      () {
        // Observe search + filtered results so the list updates while typing.
        final _ = controller.searchQuery.value;
        final recordCount = controller.filteredRecordCount.value;
        final groupCount = controller.monthGroups.length;

        if (controller.isLoading.value && controller.allRecords.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brandBlue),
          );
        }

        if (controller.errorMessage.value.isNotEmpty &&
            controller.allRecords.isEmpty) {
          return _EmptyState(
            icon: Icons.error_outline_rounded,
            iconColor: AppColors.error,
            title: 'Could not load attendance',
            message: controller.errorMessage.value,
            actionLabel: 'Retry',
            onAction: controller.loadHistory,
          );
        }

        if (recordCount == 0 && controller.hasActiveSearch) {
          return _EmptyState(
            icon: Icons.search_off_rounded,
            iconColor: AppColors.brandOrange,
            title: 'No matching records',
            message: 'Try a different name, date, or attendance detail.',
            actionLabel: 'Clear search',
            onAction: controller.clearSearch,
          );
        }

        if (recordCount == 0 || groupCount == 0) {
          return _EmptyState(
            icon: Icons.history_rounded,
            iconColor: AppColors.brandBlue,
            title: 'No records found',
            message: 'Try adjusting your filters or check in to start tracking.',
          );
        }

        return const AttendanceOdooList();
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.style(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.style(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
