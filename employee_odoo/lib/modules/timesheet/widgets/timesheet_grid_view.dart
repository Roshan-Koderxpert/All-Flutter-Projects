import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/timesheet_grid_row.dart';
import '../controllers/timesheet_controller.dart';
import '../utils/timesheet_ui_utils.dart';
import 'timesheet_add_line_form.dart';
import 'timesheet_card.dart';
import 'timesheet_grid_cell_sheet.dart';
import 'timesheet_week_navigator.dart';

bool _isGridToday(DateTime day) {
  final now = DateTime.now();
  return day.year == now.year &&
      day.month == now.month &&
      day.day == now.day;
}

class TimesheetGridView extends StatelessWidget {
  const TimesheetGridView({super.key, required this.controller});

  final TimesheetController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.weekStart.value;
      final days = controller.weekDays;
      final rows = controller.buildGridRows();
      final weekTotal = controller.weekGridTotal;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TimesheetWeekNavigator(controller: controller),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TimesheetCard(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: TimesheetGridColumns.tableWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _GridHeader(days: days),
                              if (rows.isEmpty)
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
                                ...rows.map(
                                  (row) => _GridDataRow(
                                    row: row,
                                    days: days,
                                    onCellTap: (day, hours) {
                                      if (row.projectId <= 0) {
                                        Get.snackbar(
                                          'Timesheet',
                                          'Use Add a line to log time without a project',
                                          snackPosition: SnackPosition.BOTTOM,
                                        );
                                        return;
                                      }
                                      final line = controller.findLineForCell(
                                        projectId: row.projectId,
                                        taskId: row.taskId,
                                        date: day,
                                      );
                                      final entryCount = controller.countLinesForCell(
                                        projectId: row.projectId,
                                        taskId: row.taskId,
                                        date: day,
                                      );
                                      TimesheetGridCellSheet.show(
                                        context: context,
                                        controller: controller,
                                        projectId: row.projectId,
                                        projectName: row.projectName,
                                        taskId: row.taskId,
                                        taskName: row.taskName,
                                        date: day,
                                        lineId: line?.id,
                                        existingHours: line?.hours ?? hours,
                                        existingDescription:
                                            line?.displayDescription ?? '',
                                        multipleEntriesOnDay: entryCount,
                                      );
                                    },
                                  ),
                                ),
                              _GridFooter(
                                days: days,
                                controller: controller,
                                weekTotal: weekTotal,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
}

class TimesheetGridColumns {
  TimesheetGridColumns._();

  static const double rowLabel = 130;
  static const double day = 54;
  static const double total = 72;
  static const double cellHPad = 8;

  static double get tableWidth =>
      rowLabel + day * 7 + total + cellHPad * 2;
}

class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.days});

  final List<DateTime> days;

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetGridColumns.cellHPad,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accentLight,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: TimesheetGridColumns.rowLabel,
            child: Text(
              'Project / Task',
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brandBlue,
              ),
            ),
          ),
          ...List.generate(days.length, (i) {
            final day = days[i];
            final isToday = _isGridToday(day);
            return SizedBox(
              width: TimesheetGridColumns.day,
              child: Column(
                children: [
                  Text(
                    _dayNames[i],
                    style: AppTextStyles.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? AppColors.brandBlue
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${day.month}/${day.day}',
                    style: AppTextStyles.style(
                      fontSize: 12,
                      color: isToday
                          ? AppColors.brandBlue
                          : AppColors.textSecondary,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(
            width: TimesheetGridColumns.total,
            child: Text(
              'Time Spent',
              textAlign: TextAlign.right,
              style: AppTextStyles.style(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.brandBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridDataRow extends StatelessWidget {
  const _GridDataRow({
    required this.row,
    required this.days,
    required this.onCellTap,
  });

  final TimesheetGridRow row;
  final List<DateTime> days;
  final void Function(DateTime day, double hours) onCellTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetGridColumns.cellHPad,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: TimesheetGridColumns.rowLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: AppTextStyles.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (row.subtitle.isNotEmpty)
                  Text(
                    row.subtitle,
                    style: AppTextStyles.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          ...days.map((day) {
            final hours = row.hoursOn(day);
            return _GridCell(
              hours: hours,
              isToday: _isGridToday(day),
              onTap: () => onCellTap(day, hours),
            );
          }),
          SizedBox(
            width: TimesheetGridColumns.total,
            child: Text(
              formatOdooHours(row.rowTotal),
              textAlign: TextAlign.right,
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.hours,
    required this.onTap,
    this.isToday = false,
  });

  final double hours;
  final VoidCallback onTap;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final hasHours = hours > 0;
    return SizedBox(
      width: TimesheetGridColumns.day,
      child: Material(
        color: hasHours
            ? AppColors.brandBlue.withValues(alpha: 0.1)
            : isToday
                ? AppColors.brandBlue.withValues(alpha: 0.04)
                : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: isToday && !hasHours
                ? BoxDecoration(
                    border: Border.all(
                      color: AppColors.brandBlue.withValues(alpha: 0.25),
                    ),
                  )
                : null,
            child: Text(
              hasHours ? formatOdooHours(hours) : '',
              style: AppTextStyles.style(
                fontSize: 12,
                fontWeight: hasHours ? FontWeight.w600 : FontWeight.normal,
                color:
                    hasHours ? AppColors.brandBlue : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridFooter extends StatelessWidget {
  const _GridFooter({
    required this.days,
    required this.controller,
    required this.weekTotal,
  });

  final List<DateTime> days;
  final TimesheetController controller;
  final double weekTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.inputFill,
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetGridColumns.cellHPad,
        vertical: 10,
      ),
      child: Row(
        children: [
          SizedBox(
            width: TimesheetGridColumns.rowLabel,
            child: Text(
              'Total',
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...days.map((day) {
            final total = controller.dailyTotal(day);
            return SizedBox(
              width: TimesheetGridColumns.day,
              child: Text(
                total > 0 ? formatOdooHours(total) : '',
                textAlign: TextAlign.center,
                style: AppTextStyles.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
          SizedBox(
            width: TimesheetGridColumns.total,
            child: Text(
              formatOdooHours(weekTotal),
              textAlign: TextAlign.right,
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brandBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
