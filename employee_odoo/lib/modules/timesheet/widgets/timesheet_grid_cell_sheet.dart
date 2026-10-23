import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/timesheet_controller.dart';
import '../utils/timesheet_ui_utils.dart';

class TimesheetGridCellSheet {
  TimesheetGridCellSheet._();

  static Future<void> show({
    required BuildContext context,
    required TimesheetController controller,
    required int projectId,
    required String projectName,
    int? taskId,
    String taskName = '',
    required DateTime date,
    int? lineId,
    double existingHours = 0,
    String existingDescription = '',
    int multipleEntriesOnDay = 1,
  }) {
    final isEditing = lineId != null && lineId > 0;
    final timeController = TextEditingController(
      text: existingHours > 0 ? formatOdooHours(existingHours) : '00:00',
    );
    final descController = TextEditingController(text: existingDescription);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        var saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            final dateLabel =
                '${date.month.toString().padLeft(2, '0')}/'
                '${date.day.toString().padLeft(2, '0')}/'
                '${date.year}';

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEditing ? 'Edit time' : 'Log time',
                    style: AppTextStyles.style(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF454545),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Project', value: projectName),
                  if (taskName.isNotEmpty)
                    _InfoRow(label: 'Task', value: taskName),
                  _InfoRow(label: 'Date', value: dateLabel),
                  if (isEditing && multipleEntriesOnDay > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      'This day has $multipleEntriesOnDay entries — editing the latest one.',
                      style: AppTextStyles.style(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else if (!isEditing && existingHours > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Existing: ${formatOdooHours(existingHours)} — new entry will add to this day',
                      style: AppTextStyles.style(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeController,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: 'Time Spent',
                      hintText: '00:00',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.9),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.brandBlue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.9),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.brandBlue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final hours = parseOdooHours(
                                  timeController.text,
                                );
                                if (hours == null || hours <= 0) {
                                  Get.snackbar(
                                    'Timesheet',
                                    'Enter valid time (HH:MM)',
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                  return;
                                }

                                setState(() => saving = true);
                                final ok = await controller.saveLine(
                                  lineId: lineId,
                                  projectId: projectId,
                                  taskId: taskId,
                                  date: date,
                                  description: descController.text,
                                  hours: hours,
                                );
                                if (ok && ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (context.mounted) {
                                  setState(() => saving = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandBlue,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(isEditing ? 'Update' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: AppTextStyles.style(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.style(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
