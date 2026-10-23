import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/asset_icon.dart';
import '../../../data/models/timesheet_line.dart';
import '../controllers/timesheet_controller.dart';
import '../utils/timesheet_ui_utils.dart';
import 'timesheet_add_line_form.dart';
import 'timesheet_grid_cell_sheet.dart';

class TimesheetKanbanView extends StatelessWidget {
  const TimesheetKanbanView({super.key, required this.controller});

  final TimesheetController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.weekStart.value;
      final lines = controller.sortedWeekLines;
      final weekTotal = controller.weekGridTotal;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TimesheetWeekNavigator(controller: controller),
            // const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lines.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No time logged this week',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.style(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount =
                              constraints.maxWidth >= 520 ? 3 : 2;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.35,
                            ),
                            itemCount: lines.length,
                            itemBuilder: (context, index) {
                              final line = lines[index];
                              return _TimesheetKanbanCard(
                                line: line,
                                onTap: () => _openLineSheet(context, line),
                                onQuickAdd: () => controller.quickAddMinutes(
                                  line,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    if (lines.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Week total: ${formatOdooHours(weekTotal)}',
                          style: AppTextStyles.style(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TimesheetAddLineForm(controller: controller),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _openLineSheet(BuildContext context, TimesheetLine line) {
    final projectId = line.projectId;
    if (projectId == null || projectId <= 0) {
      Get.snackbar(
        'Timesheet',
        'Use Add a line to log time without a project',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    TimesheetGridCellSheet.show(
      context: context,
      controller: controller,
      projectId: projectId,
      projectName: line.kanbanTitle,
      taskId: line.taskId,
      taskName: line.taskName,
      date: line.date ?? DateTime.now(),
      lineId: line.id,
      existingHours: line.hours,
      existingDescription: line.displayDescription,
    );
  }
}

class _TimesheetKanbanCard extends StatelessWidget {
  const _TimesheetKanbanCard({
    required this.line,
    required this.onTap,
    required this.onQuickAdd,
  });

  final TimesheetLine line;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final canQuickAdd = line.projectId != null && line.projectId! > 0;
    final footer = line.kanbanFooter;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      line.kanbanTitle,
                      style: AppTextStyles.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canQuickAdd)
                        InkWell(
                          onTap: onQuickAdd,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: AssetIcon(
                              assetPath: AppIcon.add,
                              fallback: Icons.add,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      Text(
                        formatOdooHours(line.hours),
                        style: AppTextStyles.style(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (line.kanbanSubtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  line.kanbanSubtitle,
                  style: AppTextStyles.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    line.dateLabel,
                    style: AppTextStyles.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (footer.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  footer,
                  style: AppTextStyles.style(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
