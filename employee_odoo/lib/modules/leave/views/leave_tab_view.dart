import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/asset_icon.dart';
import '../controllers/leave_controller.dart';
import '../widgets/apply_leave_sheet.dart';
import '../widgets/leave_balance_strip.dart';
import '../widgets/leave_calendar_view.dart';
import '../widgets/leave_filter_chips.dart';
import '../widgets/leave_request_list.dart';

class LeaveTabView extends GetView<LeaveController> {
  const LeaveTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _LeaveModeSwitcher(),
            ),
            const LeaveBalanceStrip(),
            Expanded(
              child: Obx(() {
                if (controller.isInitialLoad) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandBlue,
                    ),
                  );
                }

                if (controller.screenMode.value == LeaveScreenMode.calendar) {
                  return RefreshIndicator(
                    color: AppColors.brandBlue,
                    onRefresh: controller.loadLeaves,
                    child: const LeaveCalendarView(),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.brandBlue,
                  onRefresh: controller.loadLeaves,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LeaveFilterChips(),
                      Expanded(child: LeaveRequestList()),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
        const Positioned(
          right: 16,
          bottom: 16,
          child: _ApplyLeaveButton(),
        ),
      ],
      ),
    );
  }
}

class _ApplyLeaveButton extends StatelessWidget {
  const _ApplyLeaveButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: ApplyLeaveSheet.show,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.white.withValues(alpha: 0.12),
        highlightColor: AppColors.white.withValues(alpha: 0.08),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: AppColors.blueGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandBlue.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Apply',
                  style: AppTextStyles.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
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

class _LeaveModeSwitcher extends GetView<LeaveController> {
  const _LeaveModeSwitcher();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = controller.screenMode.value;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            _ModeTab(
              label: 'Calendar',
              assetPath: AppIcon.calendar,
              fallbackIcon: Icons.calendar_month_rounded,
              selected: mode == LeaveScreenMode.calendar,
              onTap: () => controller.setScreenMode(LeaveScreenMode.calendar),
            ),
            _ModeTab(
              label: 'List',
              assetPath: AppIcon.list,
              fallbackIcon: Icons.view_list_rounded,
              selected: mode == LeaveScreenMode.list,
              onTap: () => controller.setScreenMode(LeaveScreenMode.list),
            ),
          ],
        ),
      );
    });
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.assetPath,
    required this.fallbackIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final IconData fallbackIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.blueGradient : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AssetIcon(
                assetPath: assetPath,
                fallback: fallbackIcon,
                size: 18,
                color: selected ? AppColors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
