import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/utils/odoo_datetime.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../data/models/attendance_record.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/attendance_controller.dart';

/// Fixed column widths — [tableWidth] is the sum of all columns.
class AttendanceTableLayout {
  AttendanceTableLayout._();

  static const colArrow = 32.0;
  static const colEmployee = 148.0;
  static const colCheckIn = 168.0;
  static const colCheckOut = 168.0;
  static const colWorked = 96.0;
  static const colWorkedExtra = 126.0;
  static const colExtra = 100.0;
  static const colInsetEnd = 10.0;

  /// Total table width (sum of columns). Must match [_AttendanceTableRow].
  static const tableWidth = colArrow +
      colEmployee +
      colCheckIn +
      colCheckOut +
      colWorked +
      colWorkedExtra +
      colExtra;

  static const colLabelSpan =
      colEmployee + colCheckIn + colCheckOut;

  static const paddingBottom = 16.0;
}

class AttendanceOdooList extends GetView<AttendanceController> {
  const AttendanceOdooList({super.key});

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();

    return Obx(() {
      final _ = controller.searchQuery.value;
      final recordCount = controller.filteredRecordCount.value;

      if (controller.monthGroups.isEmpty || recordCount == 0) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  controller.groupByPathLabel,
                  style: AppTextStyles.style(
                    fontSize: 12,
                    color: AppColors.brandBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.brandBlue,
              backgroundColor: AppColors.white,
              onRefresh: controller.loadHistory,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: controller.monthGroups.length,
                itemBuilder: (context, index) {
                  final month = controller.monthGroups[index];
                  return _MonthSection(
                    month: month,
                    avatarBase64: home.avatarBase64.value,
                    fallbackName: home.employeeName.value,
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// One horizontal scroll per month — header + rows scroll together.
class _MonthSection extends GetView<AttendanceController> {
  const _MonthSection({
    required this.month,
    required this.avatarBase64,
    required this.fallbackName,
  });

  final AttendanceMonthGroup month;
  final String? avatarBase64;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expanded = controller.isMonthExpanded(month.monthKey);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
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
        child: expanded
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth;
                  final tableWidth = AttendanceTableLayout.tableWidth;
                  final scrollWidth =
                      tableWidth > cardWidth ? tableWidth : cardWidth;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: scrollWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: AttendanceTableLayout.paddingBottom,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _GroupHeaderRow(
                                  title:
                                      '${month.monthLabel} (${month.recordCount})',
                                  workedHours: month.totalWorkedHours,
                                  workedExtraHours:
                                      month.totalWorkedExtraHours,
                                  extraHours: month.totalExtraHours,
                                  expanded: true,
                                  onToggle: () => controller.toggleMonth(
                                    month.monthKey,
                                  ),
                                ),
                                _AttendanceTableBody(
                                  children: [
                                    const _TableHeader(),
                                    ...month.employees.asMap().entries.expand(
                                      (entry) {
                                        final isLastGroup = entry.key ==
                                            month.employees.length - 1;
                                        return [
                                          _EmployeeSection(
                                            monthKey: month.monthKey,
                                            group: entry.value,
                                            avatarBase64: avatarBase64,
                                            fallbackName: fallbackName,
                                            isLastGroup: isLastGroup,
                                          ),
                                        ];
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            : _CollapsedHeaderRow(
                title: '${month.monthLabel} (${month.recordCount})',
                onToggle: () => controller.toggleMonth(month.monthKey),
              ),
      );
    });
  }
}

class _EmployeeSection extends GetView<AttendanceController> {
  const _EmployeeSection({
    required this.monthKey,
    required this.group,
    required this.avatarBase64,
    required this.fallbackName,
    this.isLastGroup = false,
  });

  final String monthKey;
  final AttendanceEmployeeGroup group;
  final String? avatarBase64;
  final String fallbackName;
  final bool isLastGroup;

  @override
  Widget build(BuildContext context) {
    final empKey =
        controller.employeeGroupKey(monthKey, group.employeeId);
    final name = group.employeeName.isNotEmpty
        ? group.employeeName
        : fallbackName;

    return Obx(() {
      final expanded = controller.isEmployeeExpanded(empKey);

      return Column(
        children: [
          const _TableDivider(),
          _GroupHeaderRow(
            title: '$name (${group.recordCount})',
            workedHours: group.totalWorkedHours,
            workedExtraHours: group.totalWorkedExtraHours,
            extraHours: group.totalExtraHours,
            expanded: expanded,
            onToggle: () => controller.toggleEmployee(empKey),
            indent: 12,
            leading: _EmployeeAvatar(
              name: name,
              imageBase64: avatarBase64,
            ),
          ),
          if (expanded) ...[
            const _TableDivider(strong: true),
            ...group.records.asMap().entries.map(
              (entry) {
                final isLastRow = isLastGroup &&
                    entry.key == group.records.length - 1;
                return _DataRow(
                  employeeName: name,
                  record: entry.value,
                  avatarBase64: avatarBase64,
                  isLast: isLastRow,
                );
              },
            ),
          ],
        ],
      );
    });
  }
}

class _TableDivider extends StatelessWidget {
  const _TableDivider({this.strong = false});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AttendanceTableLayout.tableWidth,
      height: strong ? 1.5 : 1,
      color: strong
          ? AppColors.border
          : AppColors.border.withValues(alpha: 0.7),
    );
  }
}

/// Shared 7-column row — keeps header, totals, and data perfectly aligned.
class _AttendanceTableRow extends StatelessWidget {
  const _AttendanceTableRow({
    required this.arrow,
    required this.employee,
    required this.checkIn,
    required this.checkOut,
    required this.worked,
    required this.workedExtra,
    required this.extra,
  });

  final Widget arrow;
  final Widget employee;
  final Widget checkIn;
  final Widget checkOut;
  final Widget worked;
  final Widget workedExtra;
  final Widget extra;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: AttendanceTableLayout.colArrow,
          child: arrow,
        ),
        SizedBox(
          width: AttendanceTableLayout.colEmployee,
          child: employee,
        ),
        SizedBox(
          width: AttendanceTableLayout.colCheckIn,
          child: checkIn,
        ),
        SizedBox(
          width: AttendanceTableLayout.colCheckOut,
          child: checkOut,
        ),
        SizedBox(
          width: AttendanceTableLayout.colWorked,
          child: worked,
        ),
        SizedBox(
          width: AttendanceTableLayout.colWorkedExtra,
          child: workedExtra,
        ),
        SizedBox(
          width: AttendanceTableLayout.colExtra,
          child: extra,
        ),
      ],
    );
  }
}

class _GroupHeaderRow extends StatelessWidget {
  const _GroupHeaderRow({
    required this.title,
    required this.workedHours,
    required this.workedExtraHours,
    required this.extraHours,
    required this.expanded,
    required this.onToggle,
    this.indent = 0,
    this.leading,
  });

  final String title;
  final double workedHours;
  final double workedExtraHours;
  final double extraHours;
  final bool expanded;
  final VoidCallback onToggle;
  final double indent;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return _CollapsedHeaderRow(
        title: title,
        indent: indent,
        leading: leading,
        onToggle: onToggle,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: AttendanceTableLayout.colArrow + indent,
                child: Padding(
                  padding: EdgeInsets.only(left: indent),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: AppColors.brandOrange,
                  ),
                ),
              ),
              SizedBox(
                width: AttendanceTableLayout.colLabelSpan - indent,
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: AttendanceTableLayout.colWorked,
                child: _TotalCell(
                  OdooDateTime.formatDurationHhMm(workedHours),
                ),
              ),
              SizedBox(
                width: AttendanceTableLayout.colWorkedExtra,
                child: _TotalCell(
                  OdooDateTime.formatDurationHhMm(workedExtraHours),
                ),
              ),
              SizedBox(
                width: AttendanceTableLayout.colExtra,
                child: _TotalCell(
                  OdooDateTime.formatDurationHhMm(extraHours),
                  insetEnd: AttendanceTableLayout.colInsetEnd,
                ),
              ),
            ],
        ),
      ),
    );
  }
}

/// Collapsed row — title + arrow at top, full width, no hour columns.
class _CollapsedHeaderRow extends StatelessWidget {
  const _CollapsedHeaderRow({
    required this.title,
    required this.onToggle,
    this.indent = 0,
    this.leading,
  });

  final String title;
  final VoidCallback onToggle;
  final double indent;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12 + indent, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 22,
                color: AppColors.brandBlue,
              ),
            ),
            if (leading != null) ...[
              const SizedBox(width: 8),
              leading!,
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: leading != null ? 2 : 0),
                child: Text(
                  title,
                  style: AppTextStyles.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps header + rows in one bordered table block inside the rounded card.
class _AttendanceTableBody extends StatelessWidget {
  const _AttendanceTableBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.accentLight,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _AttendanceTableRow(
          arrow: const SizedBox.shrink(),
          employee: const _HeaderCell('Employee'),
          checkIn: const _HeaderCell('Check In'),
          checkOut: const _HeaderCell('Check Out'),
          worked: const _HeaderCell('Worked Hours', alignEnd: true),
          workedExtra: const _HeaderCell('Worked Extra Hours', alignEnd: true),
          extra: const _HeaderCell(
            'Extra Hours',
            alignEnd: true,
            insetEnd: AttendanceTableLayout.colInsetEnd,
          ),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.employeeName,
    required this.record,
    required this.avatarBase64,
    this.isLast = false,
  });

  final String employeeName;
  final AttendanceRecord record;
  final String? avatarBase64;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.toNamed(
        AppRoutes.attendanceDetail,
        arguments: record.id,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isLast ? 14 : 12),
          child: _AttendanceTableRow(
            arrow: const SizedBox.shrink(),
            employee: Row(
              children: [
                _EmployeeAvatar(
                  name: employeeName,
                  imageBase64: avatarBase64,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    employeeName,
                    style: AppTextStyles.style(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            checkIn: _BodyCell(record.checkInLabel),
            checkOut: _BodyCell(record.checkOutLabel),
            worked: _BodyCell(record.workedHoursLabel, alignEnd: true),
            workedExtra: _BodyCell(
              record.workedExtraHoursLabel,
              alignEnd: true,
            ),
            extra: _BodyCell(
              record.extraHoursLabel,
              alignEnd: true,
              insetEnd: AttendanceTableLayout.colInsetEnd,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.label, {
    this.alignEnd = false,
    this.insetEnd = 0,
  });

  final String label;
  final bool alignEnd;
  final double insetEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: insetEnd),
      child: Text(
        label,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: AppTextStyles.style(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.brandBlue,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(
    this.value, {
    this.alignEnd = false,
    this.insetEnd = 0,
  });

  final String value;
  final bool alignEnd;
  final double insetEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: insetEnd),
      child: Text(
        value,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: AppTextStyles.style(
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell(
    this.value, {
    this.insetEnd = 0,
  });

  final String value;
  final double insetEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: insetEnd),
      child: Text(
        value,
        textAlign: TextAlign.right,
        style: AppTextStyles.style(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({
    required this.name,
    required this.imageBase64,
  });

  final String name;
  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(imageBase64);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.brandBlue.withValues(alpha: 0.12),
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Text(
              initial,
              style: AppTextStyles.style(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.brandBlue,
              ),
            )
          : null,
    );
  }

  Uint8List? _decode(String? base64) {
    final sanitized = OdooImage.sanitize(base64);
    if (sanitized == null) return null;
    try {
      return base64Decode(sanitized);
    } catch (_) {
      return null;
    }
  }
}
