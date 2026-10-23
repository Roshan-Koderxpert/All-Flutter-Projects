import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/asset_icon.dart';
import '../controllers/timesheet_controller.dart';
import '../utils/timesheet_ui_utils.dart';
import '../widgets/timesheet_add_line_form.dart';
import '../widgets/timesheet_graph_view.dart';
import '../widgets/timesheet_grid_view.dart';
import '../widgets/timesheet_kanban_view.dart';
import '../widgets/timesheet_list_table.dart';

class TimesheetTabView extends GetView<TimesheetController> {
  const TimesheetTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TimesheetScreenHeader(),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value &&
                controller.weekLines.isEmpty &&
                controller.allLines.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.brandBlue),
              );
            }

            if (controller.errorMessage.value.isNotEmpty &&
                controller.weekLines.isEmpty &&
                controller.allLines.isEmpty &&
                controller.projects.isEmpty) {
              return _TimesheetEmptyState(
                icon: Icons.error_outline_rounded,
                iconColor: AppColors.error,
                title: 'Could not load timesheets',
                message: controller.errorMessage.value,
                actionLabel: 'Retry',
                onAction: controller.loadAll,
              );
            }

            final mode = controller.viewMode.value;

            if (mode == TimesheetViewMode.list) {
              return RefreshIndicator(
                color: AppColors.brandBlue,
                onRefresh: controller.loadAll,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    TimesheetListTable(controller: controller),
                    const SizedBox(height: 16),
                    TimesheetAddLineForm(controller: controller),
                  ],
                ),
              );
            }

            if (mode == TimesheetViewMode.kanban) {
              return RefreshIndicator(
                color: AppColors.brandBlue,
                onRefresh: controller.loadAll,
                child: TimesheetKanbanView(controller: controller),
              );
            }

            if (mode == TimesheetViewMode.graph) {
              return RefreshIndicator(
                color: AppColors.brandBlue,
                onRefresh: controller.loadAll,
                child: TimesheetGraphView(controller: controller),
              );
            }

            return RefreshIndicator(
              color: AppColors.brandBlue,
              onRefresh: controller.loadAll,
              child: TimesheetGridView(controller: controller),
            );
          }),
        ),
      ],
      ),
    );
  }
}

class _TimesheetScreenHeader extends GetView<TimesheetController> {
  const _TimesheetScreenHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() {
            final mode = controller.viewMode.value;
            return Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: TimesheetViewMode.values.map((item) {
                  return Expanded(
                    child: _ViewModeTab(
                      assetPath: _assetFor(item),
                      fallbackIcon: _iconFor(item),
                      label: _labelFor(item),
                      selected: mode == item,
                      onTap: () => controller.setViewMode(item),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
          const SizedBox(height: 10),
          const _WeekSummaryStrip(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  static String _assetFor(TimesheetViewMode mode) {
    return switch (mode) {
      TimesheetViewMode.grid => AppIcon.grid,
      TimesheetViewMode.kanban => AppIcon.kanban,
      TimesheetViewMode.list => AppIcon.list,
      TimesheetViewMode.graph => AppIcon.graph,
    };
  }

  static IconData _iconFor(TimesheetViewMode mode) {
    return switch (mode) {
      TimesheetViewMode.grid => Icons.grid_on_rounded,
      TimesheetViewMode.kanban => Icons.view_module_rounded,
      TimesheetViewMode.list => Icons.view_list_rounded,
      TimesheetViewMode.graph => Icons.insert_chart_rounded,
    };
  }

  static String _labelFor(TimesheetViewMode mode) {
    return switch (mode) {
      TimesheetViewMode.grid => 'Grid',
      TimesheetViewMode.kanban => 'Kanban',
      TimesheetViewMode.list => 'List',
      TimesheetViewMode.graph => 'Graph',
    };
  }
}

class _ViewModeTab extends StatelessWidget {
  const _ViewModeTab({
    required this.assetPath,
    required this.fallbackIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.blueGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.brandBlue.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetIcon(
              assetPath: assetPath,
              fallback: fallbackIcon,
              size: 20,
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekSummaryStrip extends GetView<TimesheetController> {
  const _WeekSummaryStrip();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.weekStart.value;
      controller.viewMode.value;
      final weekTotal = controller.weekGridTotal;
      final weekEntries = controller.weekLines.length;
      final allEntries = controller.allLines.length;
      final isList = controller.viewMode.value == TimesheetViewMode.list;
      final hoursTotal = isList
          ? controller.allLines.fold(0.0, (sum, line) => sum + line.hours)
          : weekTotal;

      return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.brandBlue.withValues(alpha: 0.08),
            AppColors.brandOrange.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: AssetIcon(
                assetPath: AppIcon.timer,
                fallback: Icons.schedule_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isList ? 'All logged time' : 'This week',
                  style: AppTextStyles.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatOdooHours(hoursTotal),
                  style: AppTextStyles.style(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.border,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entries',
                style: AppTextStyles.style(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${isList ? allEntries : weekEntries}',
                style: AppTextStyles.style(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    });
  }
}

class _TimesheetEmptyState extends StatelessWidget {
  const _TimesheetEmptyState({
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
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: iconColor.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.style(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.style(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
