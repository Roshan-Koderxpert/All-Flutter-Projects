import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../data/models/leave_calendar_info_item.dart';
import '../../../data/models/leave_record.dart';
import '../controllers/leave_controller.dart';
import 'apply_leave_sheet.dart';

enum LeaveCalendarPeriod { week, month, year }

class LeaveCalendarView extends StatefulWidget {
  const LeaveCalendarView({super.key});

  @override
  State<LeaveCalendarView> createState() => _LeaveCalendarViewState();
}

class _LeaveCalendarViewState extends State<LeaveCalendarView> {
  final LeaveController _controller = Get.find<LeaveController>();
  DateTime _anchorDate = DateTime.now();
  LeaveCalendarPeriod _period = LeaveCalendarPeriod.month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorDate = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshVisibleUnusualDays();
    });
  }

  Future<void> _refreshVisibleUnusualDays() async {
    final range = _visibleDateRange();
    await _controller.refreshUnusualDaysForRange(range.start, range.end);
  }

  ({DateTime start, DateTime end}) _visibleDateRange() {
    if (_period == LeaveCalendarPeriod.week) {
      final cells = _buildWeekCells(_anchorDate);
      return (start: cells.first, end: cells.last);
    }
    if (_period == LeaveCalendarPeriod.month) {
      final monthStart = DateTime(_anchorDate.year, _anchorDate.month, 1);
      final monthEnd = DateTime(_anchorDate.year, _anchorDate.month + 1, 0);
      final cells = _buildMonthCells(monthStart);
      if (cells.isEmpty) {
        return (start: monthStart, end: monthEnd);
      }
      return (start: cells.first, end: cells.last);
    }
    return (
      start: DateTime(_anchorDate.year, 1, 1),
      end: DateTime(_anchorDate.year, 12, 31),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _calendarCard(),
          const SizedBox(height: 12),
          _legendSectionCard(),
          const SizedBox(height: 12),
          _infoCard(
            title: 'Mandatory Days',
            icon: Icons.priority_high_rounded,
            items: _controller.mandatoryDays,
            emptyLabel: 'No mandatory days configured.',
            showCompany: true,
          ),
          const SizedBox(height: 12),
          _infoCard(
            title: 'Public Holidays',
            icon: Icons.celebration_outlined,
            items: _controller.publicHolidays,
            emptyLabel: 'No upcoming public holidays.',
          ),
        ],
      ),
    );
  }

  Widget _calendarCard() {
    final cells = _period == LeaveCalendarPeriod.week
        ? _buildWeekCells(_anchorDate)
        : _buildMonthCells(DateTime(_anchorDate.year, _anchorDate.month, 1));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _periodSwitcher(),
          const SizedBox(height: 10),
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => setState(_goPrevious),
              ),
              Expanded(
                child: Text(
                  _titleByPeriod(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onPressed: () => setState(_goNext),
              ),
            ],
          ),
          if (_period == LeaveCalendarPeriod.year)
            _yearOverviewGrid()
          else ...[
            const SizedBox(height: 8),
            Row(
              children: const [
                _WeekDayLabel('Mon'),
                _WeekDayLabel('Tue'),
                _WeekDayLabel('Wed'),
                _WeekDayLabel('Thu'),
                _WeekDayLabel('Fri'),
                _WeekDayLabel('Sat'),
                _WeekDayLabel('Sun'),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio:
                    _period == LeaveCalendarPeriod.week ? 1.18 : 1.08,
              ),
              itemBuilder: (_, i) => _calendarCell(cells[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _periodSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: LeaveCalendarPeriod.values.map((period) {
          final selected = _period == period;
          final label = switch (period) {
            LeaveCalendarPeriod.week => 'Week',
            LeaveCalendarPeriod.month => 'Month',
            LeaveCalendarPeriod.year => 'Year',
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _period = period;
                _refreshVisibleUnusualDays();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.brandBlue.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.style(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.brandBlue
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _legendSectionCard() {
    final byType = <int?, String>{};
    for (final r in _controller.allRequests) {
      byType[r.leaveTypeId] = r.leaveTypeName;
    }

    return _LeaveSectionCard(
      title: 'Legend',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: const [
              _LegendItem(color: AppColors.brandBlue, label: 'Approved'),
              _LegendItem(
                color: AppColors.brandOrange,
                label: 'Pending',
                striped: true,
              ),
              _LegendItem(
                color: AppColors.error,
                label: 'Refused',
                striked: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (byType.isEmpty)
            Text(
              'No leave types in current data',
              style: AppTextStyles.style(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: byType.entries.map((e) {
                return _TypeLegendItem(
                  color: _typeColorFor(e.key),
                  label: e.value,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<LeaveCalendarInfoItem> items,
    required String emptyLabel,
    bool showCompany = false,
  }) {
    return _LeaveSectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            Text(
              emptyLabel,
              style: AppTextStyles.style(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          else
            ...items.take(8).map((item) {
              final company = showCompany &&
                      item.subtitle != null &&
                      item.subtitle!.isNotEmpty
                  ? item.subtitle!
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: AppColors.brandOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: AppTextStyles.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            company != null
                                ? '$company • ${item.dateLabel}'
                                : item.dateLabel,
                            style: AppTextStyles.style(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _calendarCell(DateTime day) {
    final inMonth = _period == LeaveCalendarPeriod.month
        ? day.month == _anchorDate.month
        : true;
    final today = _isSameDate(day, DateTime.now());
    final requests = _controller.requestsOnDay(day);
    final canApply = requests.isEmpty && _controller.canApplyNewLeaveOnDay(day);
    final isDisabled = requests.isEmpty && !canApply;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _onDateTap(day),
      child: Container(
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.inputFill.withValues(alpha: 0.45)
              : today
                  ? AppColors.brandBlue.withValues(alpha: 0.06)
                  : AppColors.inputFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: today ? AppColors.brandBlue : AppColors.border,
            width: today ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 5,
              left: 6,
              child: Text(
                '${day.day}',
                style: AppTextStyles.style(
                  fontSize: 11,
                  fontWeight: today ? FontWeight.w700 : FontWeight.w600,
                  color: today
                      ? AppColors.brandBlue
                      : isDisabled
                          ? AppColors.textSecondary.withValues(alpha: 0.55)
                          : inMonth
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                ),
              ),
            ),
            if (requests.isNotEmpty)
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Wrap(
                  spacing: 3,
                  runSpacing: 2,
                  children: requests
                      .take(4)
                      .map(
                        (r) => _DotByLeave(
                          state: r.state,
                          color: _typeColorFor(r.leaveTypeId),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDateTap(DateTime day) async {
    final entries = _controller.requestsOnDay(day);
    if (entries.isEmpty) {
      final message = _controller.blockedNewLeaveDayMessage(day);
      if (message != null) {
        Get.snackbar(
          'Leave',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade900,
        );
        return;
      }
      await ApplyLeaveSheet.show(initialFrom: day, initialTo: day);
      return;
    }

    final create = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dialogTitle(day, entries),
                      style: AppTextStyles.style(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      Navigator.of(context).pop(false);
                      await _showRequestDetailDialog(entry);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          _DotByLeave(
                            state: entry.state,
                            color: _typeColorFor(entry.leaveTypeId),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${entry.leaveTypeName}: ${entry.durationLabel}',
                              style: AppTextStyles.style(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  'Create',
                  style: AppTextStyles.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (create == true) {
      final message = _controller.blockedNewLeaveDayMessage(day);
      if (message != null) {
        Get.snackbar(
          'Leave',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade900,
        );
        return;
      }
      await ApplyLeaveSheet.show(initialFrom: day, initialTo: day);
    }
  }

  String _dialogTitle(DateTime day, List<LeaveRecord> entries) {
    DateTime minDate = day;
    DateTime maxDate = day;

    for (final e in entries) {
      if (e.dateFrom.isBefore(minDate)) minDate = e.dateFrom;
      if (e.dateTo.isAfter(maxDate)) maxDate = e.dateTo;
    }

    if (_isSameDate(minDate, maxDate)) return _prettyDate(minDate);
    return '${_monthName(minDate.month)} ${minDate.day}-${maxDate.day}, ${maxDate.year}';
  }

  String _prettyDate(DateTime d) => '${_monthName(d.month)} ${d.day}, ${d.year}';

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Future<void> _showRequestDetailDialog(LeaveRecord record) async {
    final types = _controller.leaveTypes.toList();
    LeaveTypeOption? initialType;
    for (final t in types) {
      if (t.id == record.leaveTypeId) {
        initialType = t;
        break;
      }
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _LeaveRequestDetailDialog(
        record: record,
        availableTypes: types,
        initialType: initialType,
      ),
    );
  }

  List<DateTime> _buildMonthCells(DateTime monthStart) {
    final first = DateTime(monthStart.year, monthStart.month, 1);
    final startWeekDay = first.weekday;
    final gridStart = first.subtract(Duration(days: startWeekDay - 1));
    return List.generate(42, (i) => gridStart.add(Duration(days: i)));
  }

  List<DateTime> _buildWeekCells(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = d.subtract(Duration(days: d.weekday - 1));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  void _goPrevious() {
    switch (_period) {
      case LeaveCalendarPeriod.week:
        _anchorDate = _anchorDate.subtract(const Duration(days: 7));
        break;
      case LeaveCalendarPeriod.month:
        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month - 1, 1);
        break;
      case LeaveCalendarPeriod.year:
        _anchorDate = DateTime(_anchorDate.year - 1, _anchorDate.month, 1);
        break;
    }
    _refreshVisibleUnusualDays();
  }

  void _goNext() {
    switch (_period) {
      case LeaveCalendarPeriod.week:
        _anchorDate = _anchorDate.add(const Duration(days: 7));
        break;
      case LeaveCalendarPeriod.month:
        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month + 1, 1);
        break;
      case LeaveCalendarPeriod.year:
        _anchorDate = DateTime(_anchorDate.year + 1, _anchorDate.month, 1);
        break;
    }
    _refreshVisibleUnusualDays();
  }

  String _titleByPeriod() {
    if (_period == LeaveCalendarPeriod.month) {
      return _monthTitle(_anchorDate);
    }
    if (_period == LeaveCalendarPeriod.year) {
      return '${_anchorDate.year}';
    }
    final week = _buildWeekCells(_anchorDate);
    return '${_shortDate(week.first)} - ${_shortDate(week.last)}';
  }

  Widget _yearOverviewGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.4,
      ),
      itemBuilder: (_, i) {
        final month = i + 1;
        final d = DateTime(_anchorDate.year, month, 1);
        final count = _controller.allRequests
            .where((r) => _overlapsMonth(r, _anchorDate.year, month))
            .length;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _anchorDate = d;
            _period = LeaveCalendarPeriod.month;
          }),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _monthShort(month),
                  style: AppTextStyles.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count request${count == 1 ? '' : 's'}',
                  style: AppTextStyles.style(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _typeColorFor(int? typeId) {
    const palette = <Color>[
      Color(0xFF00796B),
      Color(0xFF5E35B1),
      Color(0xFF1565C0),
      Color(0xFFC62828),
      Color(0xFF2E7D32),
      Color(0xFFEF6C00),
      Color(0xFF6D4C41),
      Color(0xFF00838F),
    ];
    if (typeId == null) return AppColors.primary;
    return palette[typeId.abs() % palette.length];
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthTitle(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _shortDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  bool _overlapsMonth(LeaveRecord r, int year, int month) {
    final start = DateTime(r.dateFrom.year, r.dateFrom.month, r.dateFrom.day);
    final end = DateTime(r.dateTo.year, r.dateTo.month, r.dateTo.day);
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    return !end.isBefore(monthStart) && !start.isAfter(monthEnd);
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: AppColors.brandBlue),
        ),
      ),
    );
  }
}

class _LeaveSectionCard extends StatelessWidget {
  const _LeaveSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.white),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _WeekDayLabel extends StatelessWidget {
  const _WeekDayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.style(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DotByLeave extends StatelessWidget {
  const _DotByLeave({required this.state, required this.color});
  final LeaveState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final striped =
        state == LeaveState.toApprove || state == LeaveState.secondApproval;
    final striked = state == LeaveState.refused || state == LeaveState.cancelled;

    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: striped ? AppColors.white : color,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(9),
      ),
      child: striked
          ? Center(
              child: Container(
                width: 8,
                height: 1.4,
                color: color,
              ),
            )
          : null,
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.striped = false,
    this.striked = false,
  });

  final Color color;
  final String label;
  final bool striped;
  final bool striked;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: striped ? AppColors.white : color,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(10),
          ),
          child: striked
              ? Center(
                  child: Container(
                    width: 9,
                    height: 1.4,
                    color: color,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.style(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _TypeLegendItem extends StatelessWidget {
  const _TypeLegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.style(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LeaveRequestDetailDialog extends StatefulWidget {
  const _LeaveRequestDetailDialog({
    required this.record,
    required this.availableTypes,
    required this.initialType,
  });

  final LeaveRecord record;
  final List<LeaveTypeOption> availableTypes;
  final LeaveTypeOption? initialType;

  @override
  State<_LeaveRequestDetailDialog> createState() =>
      _LeaveRequestDetailDialogState();
}

class _LeaveRequestDetailDialogState extends State<_LeaveRequestDetailDialog> {
  late LeaveTypeOption? _selectedType;
  late DateTime _from;
  late DateTime _to;
  late TextEditingController _descriptionCtrl;
  LeaveController get _controller => Get.find<LeaveController>();

  bool get _isEditable =>
      widget.record.state == LeaveState.draft || widget.record.state.isPending;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _from = widget.record.dateFrom;
    _to = widget.record.dateTo;
    _descriptionCtrl = TextEditingController(text: widget.record.description);
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Time Off Request',
                        style: AppTextStyles.style(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _detailRow(
                  'Time Off Type',
                  _isEditable
                      ? AppDropdownFormField<LeaveTypeOption>(
                          initialValue: _selectedType,
                          items: widget.availableTypes
                              .map(
                                (t) => AppDropdownStyle.item(
                                  value: t,
                                  child: Text(
                                    t.name,
                                    style: AppTextStyles.style(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedType = v),
                          decoration: _inputDecoration(),
                        )
                      : Text(
                          widget.record.leaveTypeName,
                          style: AppTextStyles.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                _detailRow(
                  'Dates',
                  _isEditable
                      ? Row(
                          children: [
                            Expanded(
                              child: _dateBtn(
                                label: _formatDate(_from),
                                onTap: () => _pickDate(isStart: true),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward, size: 16),
                            ),
                            Expanded(
                              child: _dateBtn(
                                label: _formatDate(_to),
                                onTap: () => _pickDate(isStart: false),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '${_formatDate(_from)} ⟶ ${_formatDate(_to)}',
                          style: AppTextStyles.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                _detailRow(
                  'Requested\n(Days/Hours)',
                  Text(
                    widget.record.durationLabel,
                    style: AppTextStyles.style(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _detailRow(
                  'Description',
                  _isEditable
                      ? TextField(
                          controller: _descriptionCtrl,
                          maxLines: 2,
                          decoration: _inputDecoration(hint: 'Description'),
                        )
                      : Text(
                          _descriptionCtrl.text.isEmpty ? '—' : _descriptionCtrl.text,
                          style: AppTextStyles.style(fontSize: 14),
                        ),
                ),
                const SizedBox(height: 16),
                Obx(() {
                  final saving = _controller.savingLeaveId.value == widget.record.id;
                  final deleting =
                      _controller.cancellingLeaveId.value == widget.record.id;
                  return Row(
                    children: [
                      if (_isEditable) ...[
                        FilledButton(
                          onPressed: saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Discard'),
                      ),
                      if (_controller.canCancel(widget.record)) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: deleting ? null : _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: deleting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Delete'),
                        ),
                      ],
                    ],
                  );
                }),
              ],
            ),
          ),
          _StatusRibbon(state: widget.record.state),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final firstDate = _controller.earliestEditableRequestDate(widget.record);
    final lastDate = _controller.latestNewRequestDate;
    final originalWasPendingPast =
        (widget.record.state == LeaveState.draft ||
                widget.record.state.isPending) &&
            LeaveController.normalizeCalendarDay(widget.record.dateFrom)
                .isBefore(_controller.earliestNewRequestDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _from : _to,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) {
        if (_controller.isMandatoryDay(day) || _controller.isDateBlocked(day)) {
          return false;
        }
        if (_controller.isPastCalendarDay(day)) {
          return originalWasPendingPast;
        }
        if (isStart && _controller.isUnusualDay(day)) return false;
        return true;
      },
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _save() async {
    final type = _selectedType;
    if (type == null) {
      Get.snackbar('Leave', 'Select leave type');
      return;
    }
    final ok = await _controller.updateLeaveRequest(
      original: widget.record,
      type: type,
      dateFrom: _from,
      dateTo: _to,
      description: _descriptionCtrl.text.trim(),
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await _controller.cancelLeaveRequest(
      widget.record,
      successMessage: 'Leave request deleted',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Widget _detailRow(String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTextStyles.style(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: value),
      ],
    );
  }

  Widget _dateBtn({required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTextStyles.style(fontSize: 13),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    );
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}

class _StatusRibbon extends StatelessWidget {
  const _StatusRibbon({required this.state});
  final LeaveState state;

  @override
  Widget build(BuildContext context) {
    if (state == LeaveState.toApprove || state == LeaveState.secondApproval) {
      return const SizedBox.shrink();
    }

    final (text, color) = switch (state) {
      LeaveState.refused || LeaveState.cancelled => ('REFUSED', AppColors.error),
      LeaveState.approved => ('APPROVED', AppColors.accent),
      _ => ('DRAFT', AppColors.textSecondary),
    };
    return Positioned(
      right: -34,
      top: 34,
      child: Transform.rotate(
        angle: 0.78,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 7),
          color: color.withValues(alpha: 0.9),
          child: Text(
            text,
            style: AppTextStyles.style(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
