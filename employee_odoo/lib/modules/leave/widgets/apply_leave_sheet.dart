import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../data/models/leave_record.dart';
import '../controllers/leave_controller.dart';
import '../../home/controllers/main_controller.dart';

class ApplyLeaveSheet extends StatefulWidget {
  const ApplyLeaveSheet({
    super.key,
    this.initialFrom,
    this.initialTo,
  });

  static Future<void> show({
    DateTime? initialFrom,
    DateTime? initialTo,
  }) {
    final context = Get.context;
    if (context == null) return Future.value();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ApplyLeaveSheet(
        initialFrom: initialFrom,
        initialTo: initialTo,
      ),
    ).whenComplete(_onSheetClosed);
  }

  static void _onSheetClosed() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!Get.isRegistered<MainController>()) return;
    final main = Get.find<MainController>();
    final index = main.currentIndex.value.clamp(0, main.screenTitles.length - 1);
    main.notchBarController.oldIndex = null;
    main.notchBarController.jumpTo(index);
  }

  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<ApplyLeaveSheet> {
  final _descriptionController = TextEditingController();
  LeaveTypeOption? _selectedType;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Unit options, driven by the selected type's admin configuration.
  bool _halfDay = false;
  HalfDayPeriod _halfDayPeriod = HalfDayPeriod.morning;
  bool _customHours = false;
  double _hourFrom = 8.0;
  double _hourTo = 17.0;

  // Supporting documents (shown only for types with the option enabled).
  final _imagePicker = ImagePicker();
  final List<_PickedDocument> _documents = [];
  static const _maxDocumentBytes = 10 * 1024 * 1024;

  LeaveController get _controller => Get.find<LeaveController>();

  bool get _isHalfDayMode =>
      _selectedType?.requestUnit == LeaveRequestUnit.halfDay && _halfDay;

  bool get _isHoursMode =>
      _selectedType?.requestUnit == LeaveRequestUnit.hour && _customHours;

  bool get _isSingleDayMode => _isHalfDayMode || _isHoursMode;

  /// Half-hour steps over the full day, matching the Odoo web dropdown.
  static final List<double> _hourSteps =
      List.generate(48, (i) => i * 0.5);

  static String _hourLabel(double h) {
    final totalMinutes = (h * 60).round();
    final hour24 = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    final suffix = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:${minutes.toString().padLeft(2, '0')} $suffix';
  }

  @override
  void initState() {
    super.initState();
    final from = widget.initialFrom;
    final to = widget.initialTo ?? widget.initialFrom;
    if (from != null && _controller.canApplyNewLeaveOnDay(from)) {
      _dateFrom = from;
      if (to != null && !to.isBefore(from)) {
        _dateTo = _controller.canSelectEndDateForNewRequest(to) ? to : from;
      } else {
        _dateTo = from;
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final firstDate = _controller.earliestNewRequestDate;
    final lastDate = _controller.latestNewRequestDate;

    final preferred = isStart
        ? (_dateFrom ?? _controller.earliestNewRequestDate)
        : (_dateTo ?? _dateFrom ?? _controller.earliestNewRequestDate);
    final initial = _nearestSelectableDate(
      preferred: preferred,
      firstDate: firstDate,
      lastDate: lastDate,
      isStart: isStart,
    );

    if (initial == null) {
      Get.snackbar(
        'Leave',
        'No selectable dates available right now.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) => isStart
          ? _controller.canApplyNewLeaveOnDay(day)
          : _controller.canSelectEndDateForNewRequest(day),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) {
          _dateTo = picked;
        }
      } else {
        _dateTo = picked;
      }
    });
  }

  DateTime? _nearestSelectableDate({
    required DateTime preferred,
    required DateTime firstDate,
    required DateTime lastDate,
    required bool isStart,
  }) {
    DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);

    final first = normalize(firstDate);
    final last = normalize(lastDate);
    var start = normalize(preferred);
    if (start.isBefore(first)) start = first;
    if (start.isAfter(last)) start = last;

    bool isSelectable(DateTime d) => isStart
        ? _controller.canApplyNewLeaveOnDay(d)
        : _controller.canSelectEndDateForNewRequest(d);
    if (isSelectable(start)) return start;

    for (var offset = 1; offset <= 730; offset++) {
      final forward = start.add(Duration(days: offset));
      if (!forward.isAfter(last) && isSelectable(forward)) {
        return forward;
      }
      final backward = start.subtract(Duration(days: offset));
      if (!backward.isBefore(first) && isSelectable(backward)) {
        return backward;
      }
      if (forward.isAfter(last) && backward.isBefore(first)) break;
    }
    return null;
  }

  String _formatPickerDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      Get.snackbar('Leave', 'Please select a leave type');
      return;
    }
    if (_dateFrom == null || (!_isSingleDayMode && _dateTo == null)) {
      Get.snackbar(
        'Leave',
        _isSingleDayMode
            ? 'Please select a date'
            : 'Please select start and end dates',
      );
      return;
    }
    if (_isHoursMode && _hourTo <= _hourFrom) {
      Get.snackbar('Leave', 'End time must be after start time');
      return;
    }

    final attachments = _selectedType!.supportsDocument
        ? await _documentUploads()
        : const <LeaveAttachmentUpload>[];

    final ok = await _controller.submitLeaveRequest(
      type: _selectedType!,
      dateFrom: _dateFrom!,
      dateTo: _isSingleDayMode ? _dateFrom! : _dateTo!,
      description: _descriptionController.text,
      showSuccessSnackbar: false,
      halfDay: _isHalfDayMode,
      halfDayPeriod: _halfDayPeriod,
      customHours: _isHoursMode,
      hourFrom: _isHoursMode ? _hourFrom : null,
      hourTo: _isHoursMode ? _hourTo : null,
      attachments: attachments,
    );

    if (ok && mounted) {
      Get.back();
      Get.snackbar(
        'Success',
        'Leave request submitted',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
    }
  }

  LeaveTypeOption? _matchSelected(List<LeaveTypeOption> types) {
    if (_selectedType == null) return null;
    for (final t in types) {
      if (t.id == _selectedType!.id) return t;
    }
    return null;
  }

  static String _mimeTypeFor(String extension) {
    return switch (extension.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _addDocument(File file, String name) async {
    final size = await file.length();
    if (size > _maxDocumentBytes) {
      Get.snackbar(
        'Leave',
        'File is too large. Maximum size is 10 MB.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    setState(() {
      _documents.add(_PickedDocument(
        file: file,
        name: name,
        mimeType: _mimeTypeFor(name.split('.').last),
      ));
    });
  }

  Future<void> _pickDocument() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.brandBlue),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.brandBlue),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded,
                  color: AppColors.brandBlue),
              title: const Text('Browse Files'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    switch (source) {
      case 'camera':
      case 'gallery':
        final picked = await _imagePicker.pickImage(
          source:
              source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 80,
        );
        if (picked != null) {
          await _addDocument(File(picked.path), picked.name);
        }
      case 'file':
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        );
        final path = result?.files.single.path;
        if (result != null && path != null) {
          await _addDocument(File(path), result.files.single.name);
        }
    }
  }

  Future<List<LeaveAttachmentUpload>> _documentUploads() async {
    final uploads = <LeaveAttachmentUpload>[];
    for (final doc in _documents) {
      uploads.add(LeaveAttachmentUpload(
        bytes: await doc.file.readAsBytes(),
        fileName: doc.name,
        mimeType: doc.mimeType,
      ));
    }
    return uploads;
  }

  /// Attach controls shown only when the type has "Supporting Document"
  /// enabled in the Odoo backend.
  List<Widget> _buildDocumentSection() {
    final type = _selectedType;
    if (type == null || !type.supportsDocument) return const [];

    return [
      const SizedBox(height: 16),
      Text(
        'Supporting Document',
        style: AppTextStyles.style(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Obx(() {
        final submitting = _controller.isSubmitting.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _documents.length; i++) ...[
              _DocumentTile(
                document: _documents[i],
                onRemove: submitting
                    ? null
                    : () => setState(() => _documents.removeAt(i)),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: submitting ? null : _pickDocument,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Attach File'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandBlue,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      }),
    ];
  }

  /// Extra controls shown only when the selected type is configured for
  /// half days or hours in the Odoo backend.
  List<Widget> _buildUnitSection() {
    final type = _selectedType;
    if (type == null || type.requestUnit == LeaveRequestUnit.day) {
      return const [];
    }

    final isHalfDayUnit = type.requestUnit == LeaveRequestUnit.halfDay;

    return [
      const SizedBox(height: 16),
      Obx(() {
        final submitting = _controller.isSubmitting.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile.adaptive(
                value: isHalfDayUnit ? _halfDay : _customHours,
                onChanged: submitting
                    ? null
                    : (v) => setState(() {
                          if (isHalfDayUnit) {
                            _halfDay = v;
                          } else {
                            _customHours = v;
                          }
                        }),
                activeTrackColor: AppColors.primary,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                title: Text(
                  isHalfDayUnit ? 'Half Day' : 'Custom Hours',
                  style: AppTextStyles.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  isHalfDayUnit
                      ? 'Take a morning or afternoon off'
                      : 'Request specific hours on one day',
                  style: AppTextStyles.style(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            if (isHalfDayUnit && _halfDay) ...[
              const SizedBox(height: 10),
              Row(
                children: HalfDayPeriod.values.map((period) {
                  final selected = _halfDayPeriod == period;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: period == HalfDayPeriod.morning ? 10 : 0,
                      ),
                      child: GestureDetector(
                        onTap: submitting
                            ? null
                            : () =>
                                setState(() => _halfDayPeriod = period),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                period == HalfDayPeriod.morning
                                    ? Icons.wb_sunny_outlined
                                    : Icons.wb_twilight_rounded,
                                size: 16,
                                color: selected
                                    ? AppColors.white
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                period.label,
                                style: AppTextStyles.style(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppColors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (!isHalfDayUnit && _customHours) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildHourField(
                      label: 'From',
                      value: _hourFrom,
                      enabled: !submitting,
                      onChanged: (v) => setState(() {
                        _hourFrom = v;
                        if (_hourTo <= v) {
                          _hourTo = (v + 0.5).clamp(0.0, 23.5);
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHourField(
                      label: 'To',
                      value: _hourTo,
                      enabled: !submitting,
                      onChanged: (v) => setState(() => _hourTo = v),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      }),
    ];
  }

  Widget _buildHourField({
    required String label,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.style(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        AppDropdownFormField<double>(
          // FormField state only reads initialValue on creation; re-key so a
          // programmatic change (From pushing To forward) is reflected.
          key: ValueKey('$label-$value'),
          initialValue: value,
          decoration: _inputDecoration(),
          items: _hourSteps
              .map(
                (h) => AppDropdownStyle.item(
                  value: h,
                  child: Text(
                    _hourLabel(h),
                    style: AppTextStyles.style(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final keyboardOpen = viewInsets.bottom > 0;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + (keyboardOpen ? 0 : padding.bottom),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Apply for Leave',
                style: AppTextStyles.style(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Leave Type',
                style: AppTextStyles.style(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Obx(() {
                final types = _controller.leaveTypes.toList();
                final submitting = _controller.isSubmitting.value;
                final selected = _matchSelected(types);

                if (types.isEmpty) {
                  return Text(
                    'No leave types available. Contact HR for allocation.',
                    style: AppTextStyles.style(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  );
                }

                return AppDropdownFormField<LeaveTypeOption>(
                  initialValue: selected,
                  decoration: _inputDecoration(),
                  items: types
                      .map(
                        (t) => AppDropdownStyle.item(
                          value: t,
                          child: Text(
                            t.remainingLabel,
                            style: AppTextStyles.style(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: submitting
                      ? null
                      : (v) => setState(() {
                            _selectedType = v;
                            // Unit toggles are per-type; reset on change.
                            _halfDay = false;
                            _customHours = false;
                          }),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Booked leave dates are disabled in the calendar.',
                style: AppTextStyles.style(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Obx(() {
                final submitting = _controller.isSubmitting.value;
                return Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: _isSingleDayMode ? 'Date' : 'Start Date',
                        value: _formatPickerDate(_dateFrom),
                        onTap:
                            submitting ? null : () => _pickDate(isStart: true),
                      ),
                    ),
                    if (!_isSingleDayMode) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'End Date',
                          value: _formatPickerDate(_dateTo),
                          onTap: submitting
                              ? null
                              : () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ],
                );
              }),
              ..._buildUnitSection(),
              const SizedBox(height: 16),
              Text(
                'Description (optional)',
                style: AppTextStyles.style(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Obx(() {
                final submitting = _controller.isSubmitting.value;
                return TextField(
                  controller: _descriptionController,
                  enabled: !submitting,
                  maxLines: 3,
                  decoration: _inputDecoration(hint: 'Reason for leave...'),
                );
              }),
              ..._buildDocumentSection(),
              const SizedBox(height: 24),
              Obx(() {
                final types = _controller.leaveTypes;
                final submitting = _controller.isSubmitting.value;
                return FilledButton(
                  onPressed: submitting || types.isEmpty ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          'Submit Request',
                          style: AppTextStyles.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                );
              }),
            ],
          ),
        ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _PickedDocument {
  const _PickedDocument({
    required this.file,
    required this.name,
    required this.mimeType,
  });

  final File file;
  final String name;
  final String mimeType;
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, this.onRemove});

  final _PickedDocument document;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = document.mimeType.startsWith('image/');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                document.file,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppColors.brandBlue,
                size: 20,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              document.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.style(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(
              value,
              style: AppTextStyles.style(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
