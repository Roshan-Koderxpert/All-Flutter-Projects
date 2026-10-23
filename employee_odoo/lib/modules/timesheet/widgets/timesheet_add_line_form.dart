import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/asset_icon.dart';
import '../controllers/timesheet_controller.dart';
import '../utils/timesheet_ui_utils.dart';

/// Compact entry point — opens [TimesheetAddLineDialog] on tap.
class TimesheetAddLineForm extends StatelessWidget {
  const TimesheetAddLineForm({super.key, required this.controller});

  final TimesheetController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => TimesheetAddLineDialog.show(
          context: context,
          controller: controller,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: AssetIcon(
                      assetPath: AppIcon.add,
                      fallback: Icons.add_rounded,
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
                        'Add a line',
                        style: AppTextStyles.style(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandBlue,
                        ),
                      ),
                      Text(
                        'Log time on a project',
                        style: AppTextStyles.style(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.brandBlue.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog form for logging a new timesheet line.
class TimesheetAddLineDialog extends StatefulWidget {
  const TimesheetAddLineDialog({
    super.key,
    required this.controller,
    this.initialDate,
  });

  final TimesheetController controller;
  final DateTime? initialDate;

  static Future<void> show({
    required BuildContext context,
    required TimesheetController controller,
    DateTime? initialDate,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TimesheetAddLineDialog(
        controller: controller,
        initialDate: initialDate,
      ),
    );
  }

  @override
  State<TimesheetAddLineDialog> createState() => _TimesheetAddLineDialogState();
}

class _TimesheetAddLineDialogState extends State<TimesheetAddLineDialog> {
  bool _saving = false;

  int? _projectId;
  int? _taskId;
  late DateTime _date;
  final _descController = TextEditingController();
  final _timeController = TextEditingController(text: '00:00');

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _descController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _onProjectChanged(int? projectId) async {
    setState(() {
      _projectId = projectId;
      _taskId = null;
    });
    if (projectId == null) {
      widget.controller.clearTasks();
      return;
    }
    await widget.controller.loadTasksForProject(projectId);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  String get _dateLabel {
    return '${_date.day.toString().padLeft(2, '0')}/'
        '${_date.month.toString().padLeft(2, '0')}/'
        '${_date.year}';
  }

  Future<void> _save() async {
    if (_projectId == null) {
      Get.snackbar(
        'Timesheet',
        'Select a project',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final hours = parseOdooHours(_timeController.text);
    if (hours == null || hours <= 0) {
      Get.snackbar(
        'Timesheet',
        'Enter valid time (HH:MM)',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ok = await widget.controller.addLine(
        projectId: _projectId!,
        taskId: _taskId,
        date: _date,
        description: _descController.text,
        hours: hours,
      );
      if (ok && mounted) {
        widget.controller.clearTasks();
        Navigator.of(context).pop();
        Get.snackbar(
          'Timesheet',
          'Time logged successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.brandBlue.withValues(alpha: 0.12),
          colorText: AppColors.brandBlue,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final radius = BorderRadius.circular(12);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.brandBlue, width: 2),
      ),
      labelStyle: AppTextStyles.style(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
      hintStyle: AppTextStyles.style(
        fontSize: 14,
        color: AppColors.textSecondary.withValues(alpha: 0.75),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(onClose: () => Navigator.of(context).pop()),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
                child: Obx(() {
                  final projects = widget.controller.projects;
                  final tasks = widget.controller.tasks;
                  final loadingTasks =
                      widget.controller.isLoadingTasks.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel(
                        icon: Icons.folder_outlined,
                        label: 'Project',
                      ),
                      const SizedBox(height: 8),
                      _OdooDropdown<int>(
                        hint: 'Select project',
                        value: _projectId,
                        decoration: _fieldDecoration(),
                        items: projects
                            .map(
                              (p) => AppDropdownStyle.item(
                                value: p.id,
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _onProjectChanged,
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel(
                        icon: Icons.task_alt_outlined,
                        label: 'Task (optional)',
                      ),
                      const SizedBox(height: 8),
                      _OdooDropdown<int>(
                        hint: loadingTasks
                            ? 'Loading tasks...'
                            : _projectId == null
                                ? 'Select project first'
                                : 'Select task',
                        value: _taskId,
                        decoration: _fieldDecoration(),
                        items: tasks
                            .map(
                              (t) => AppDropdownStyle.item(
                                value: t.id,
                                child: Text(
                                  t.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        enabled: _projectId != null && !loadingTasks,
                        onChanged: _projectId == null
                            ? null
                            : (v) => setState(() => _taskId = v),
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date & time',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: _fieldDecoration(
                                  label: 'Date',
                                  suffixIcon: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: AppColors.brandBlue,
                                    size: 20,
                                  ),
                                ),
                                child: Text(
                                  _dateLabel,
                                  style: AppTextStyles.style(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _timeController,
                              keyboardType: TextInputType.datetime,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9:]'),
                                ),
                              ],
                              decoration: _fieldDecoration(
                                label: 'Time spent',
                                hint: '00:00',
                                prefixIcon: const Icon(
                                  Icons.schedule_rounded,
                                  color: AppColors.brandBlue,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use HH:MM format — e.g. 01:30 for 1 hour 30 minutes',
                        style: AppTextStyles.style(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel(
                        icon: Icons.notes_rounded,
                        label: 'Description',
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descController,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _fieldDecoration(
                          hint: 'What did you work on?',
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
            _DialogActions(
              saving: _saving,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_chart_rounded,
              color: AppColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add timesheet line',
                  style: AppTextStyles.style(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Record time against a project',
                  style: AppTextStyles.style(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textSecondary,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.inputFill.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Save line'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brandBlue),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.style(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.brandBlue,
          ),
        ),
      ],
    );
  }
}

class _OdooDropdown<T> extends StatelessWidget {
  const _OdooDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.decoration,
    this.onChanged,
    this.enabled = true,
  });

  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final InputDecoration decoration;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Hint is shown only by [AppDropdownButton] — not [InputDecoration.hintText],
    // otherwise both render in the same slot and overlap.
    return InputDecorator(
      decoration: decoration.copyWith(hintText: null, labelText: null),
      isEmpty: false,
      child: DropdownButtonHideUnderline(
        child: SizedBox(
          width: double.infinity,
          child: AppDropdownButton<T>(
            isExpanded: true,
            value: value,
            hint: Text(
              hint,
              style: AppTextStyles.style(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            items: items,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ),
    );
  }
}
