import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/timesheet_line.dart';
import '../controllers/timesheet_controller.dart';
import '../utils/timesheet_ui_utils.dart';
import 'timesheet_card.dart';
import 'timesheet_grid_cell_sheet.dart';

class TimesheetListTable extends StatelessWidget {
  const TimesheetListTable({super.key, required this.controller});

  final TimesheetController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.viewMode.value;
      final lines = controller.viewMode.value == TimesheetViewMode.list
          ? controller.allLines
          : controller.weekLines;
      final total = lines.fold(0.0, (sum, line) => sum + line.hours);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TimesheetCard(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: TimesheetColumns.tableWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _TableHeader(),
                    if (lines.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No timesheet lines yet',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.style(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...lines.map(
                        (line) => _TableRow(
                          line: line,
                          onTap: () => _openLineSheet(context, line),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Total: ${formatOdooHours(total)}',
                  style: AppTextStyles.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
            ),
          ),
        ],
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
      projectName: line.projectName.isNotEmpty
          ? line.projectName
          : line.kanbanTitle,
      taskId: line.taskId,
      taskName: line.taskName,
      date: line.date ?? DateTime.now(),
      lineId: line.id,
      existingHours: line.hours,
      existingDescription: line.displayDescription,
    );
  }
}

class TimesheetColumns {
  TimesheetColumns._();

  static const double date = 100;
  static const double project = 150;
  static const double task = 150;
  static const double description = 180;
  static const double hours = 90;
  static const double cellHPad = 12;

  static double get tableWidth =>
      date + project + task + description + hours + cellHPad * 2;
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetColumns.cellHPad,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accentLight,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: const Row(
        children: [
          _HeaderCell(label: 'Date', width: TimesheetColumns.date),
          _HeaderCell(label: 'Project', width: TimesheetColumns.project),
          _HeaderCell(label: 'Task', width: TimesheetColumns.task),
          _HeaderCell(
            label: 'Description',
            width: TimesheetColumns.description,
          ),
          _HeaderCell(
            label: 'Time Spent',
            width: TimesheetColumns.hours,
            align: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.width,
    this.align = TextAlign.left,
  });

  final String label;
  final double width;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: align,
        style: AppTextStyles.style(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.brandBlue,
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.line, required this.onTap});

  final TimesheetLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TimesheetColumns.cellHPad,
            vertical: 11,
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
              _Cell(width: TimesheetColumns.date, text: line.dateLabel),
              _Cell(
                width: TimesheetColumns.project,
                text: line.projectName.isNotEmpty ? line.projectName : '—',
              ),
              _Cell(
                width: TimesheetColumns.task,
                text: line.taskName.isNotEmpty ? line.taskName : '—',
              ),
              _Cell(
                width: TimesheetColumns.description,
                text: line.displayDescription.isNotEmpty
                    ? line.displayDescription
                    : '/',
              ),
              _Cell(
                width: TimesheetColumns.hours,
                text: formatOdooHours(line.hours),
                align: TextAlign.right,
                bold: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.width,
    required this.text,
    this.align = TextAlign.left,
    this.bold = false,
  });

  final double width;
  final String text;
  final TextAlign align;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: AppTextStyles.style(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: bold ? AppColors.brandBlue : AppColors.textPrimary,
        ),
      ),
    );
  }
}
