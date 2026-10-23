import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_controller.dart';

class StatsRow extends GetView<HomeController> {
  const StatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final main = Get.find<MainController>();

    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _StatCard(
              color: AppColors.brandBlue,
              icon: Icons.pending_actions_rounded,
              label: 'Pending Approvals',
              value: '${controller.pendingApprovals.value}',
              onTap: () {
                if (main.approvalsTabIndex >= 0) {
                  main.changeTab(main.approvalsTabIndex);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              color: AppColors.brandOrange,
              icon: Icons.task_alt_rounded,
              label: 'Timesheet Tasks',
              value: '${controller.pendingTasks.value}',
              onTap: () => main.changeTab(main.timesheetTabIndex),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),

          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 14),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.style(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.style(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
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
