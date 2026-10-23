import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../leave/controllers/leave_controller.dart';
import '../../leave/widgets/apply_leave_sheet.dart';
import '../controllers/main_controller.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final main = Get.find<MainController>();

    return Obx(() {
      final actions = <_ActionData>[
        if (main.canUse('attendance'))
          _ActionData(
            icon: Icons.fingerprint_rounded,
            label: 'Attendance',
            onTap: () => main.changeTab(1),
          ),
        if (main.canAccessApprovals.value)
          _ActionData(
            icon: Icons.approval_rounded,
            label: 'Approvals',
            onTap: () => main.changeTab(main.approvalsTabIndex),
          ),
        if (main.canUse('leave'))
          _ActionData(
            icon: Icons.event_available_rounded,
            label: 'Apply Leave',
            onTap: () async {
              main.changeTab(2);
              final leave = Get.find<LeaveController>();
              await leave.loadLeaves();
              await ApplyLeaveSheet.show();
            },
          ),
        if (main.canUse('expense'))
          _ActionData(
            icon: Icons.receipt_long_rounded,
            label: 'Expenses',
            onTap: () => Get.toNamed(AppRoutes.expenseList),
          ),
        if (main.canUse('directory'))
          _ActionData(
            icon: Icons.people_alt_rounded,
            label: 'Directory',
            onTap: () => Get.toNamed(AppRoutes.directoryList),
          ),
        // My Tasks is a full-user feature (runs on the user's own account).
        if (!main.isEmployeeMode)
          _ActionData(
            icon: Icons.checklist_rtl_rounded,
            label: 'My Tasks',
            onTap: () => Get.toNamed(AppRoutes.taskList),
          ),
        if (main.canUse('payslip'))
          _ActionData(
            icon: Icons.receipt_long_rounded,
            label: 'Payslips',
            onTap: () => Get.toNamed(AppRoutes.payslipList),
          ),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Action',
            style: AppTextStyles.style(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF454545),
            ),
          ),
          const SizedBox(height: 8),
          // 3-up on phones (unchanged); more columns on a tablet so the tiles
          // fill the width without each one stretching into a flat slab.
          for (var row = 0;
              row * AppBreakpoints.tileColumns(context) < actions.length;
              row++) ...[
            if (row > 0) const SizedBox(height: 10),
            _QuickActionRow(
              actions: actions,
              startIndex: row * AppBreakpoints.tileColumns(context),
              perRow: AppBreakpoints.tileColumns(context),
            ),
          ],
        ],
      );
    });
  }
}

class _ActionData {
  const _ActionData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Renders up to [perRow] tiles (actions[startIndex..startIndex+perRow)) in a
/// row, padding out a short final row with blank spacers so tiles stay aligned
/// to the grid.
class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.actions,
    required this.startIndex,
    required this.perRow,
  });

  final List<_ActionData> actions;
  final int startIndex;
  final int perRow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(perRow, (i) {
        final index = startIndex + i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
            child: index < actions.length
                ? _QuickAction(
                    data: actions[index],
                    color: index.isEven
                        ? AppColors.brandBlue
                        : AppColors.brandOrange,
                  )
                : const SizedBox.shrink(),
          ),
        );
      }),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.data, required this.color});

  final _ActionData data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppBreakpoints.tileHeight(context),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: data.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  data.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
