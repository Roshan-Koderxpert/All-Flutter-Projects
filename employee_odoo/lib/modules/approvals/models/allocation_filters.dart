import '../../../data/models/leave_allocation_record.dart';

/// Status filters — same entries and grouping as the Odoo web Allocations
/// search panel. Within this group selections are OR'ed, like Odoo.
enum AllocationStatusFilter {
  waitingForMe,
  firstApproval,
  secondApproval,
  approved,
  refused;

  String get label => switch (this) {
        AllocationStatusFilter.waitingForMe => 'Waiting For Me',
        AllocationStatusFilter.firstApproval => 'First Approval',
        AllocationStatusFilter.secondApproval => 'Second Approval',
        AllocationStatusFilter.approved => 'Approved',
        AllocationStatusFilter.refused => 'Refused',
      };

  bool matches(LeaveAllocationRecord r) => switch (this) {
        AllocationStatusFilter.waitingForMe =>
          r.state == LeaveAllocationState.toApprove ||
              r.state == LeaveAllocationState.secondApproval,
        AllocationStatusFilter.firstApproval =>
          r.state == LeaveAllocationState.toApprove,
        AllocationStatusFilter.secondApproval =>
          r.state == LeaveAllocationState.secondApproval,
        AllocationStatusFilter.approved =>
          r.state == LeaveAllocationState.approved,
        AllocationStatusFilter.refused =>
          r.state == LeaveAllocationState.refused,
      };
}

/// Group By options — same as the Odoo web Allocations list (minus Custom Group).
enum AllocationGroupBy {
  employee,
  type,
  allocationType,
  status;

  String get label => switch (this) {
        AllocationGroupBy.employee => 'Employee',
        AllocationGroupBy.type => 'Type',
        AllocationGroupBy.allocationType => 'Allocation Type',
        AllocationGroupBy.status => 'Status',
      };

  String keyFor(LeaveAllocationRecord r) => switch (this) {
        AllocationGroupBy.employee =>
          r.employeeName.isNotEmpty ? r.employeeName : 'Undefined',
        AllocationGroupBy.type => r.leaveTypeName,
        AllocationGroupBy.allocationType =>
          r.allocationType.isNotEmpty ? r.allocationType : 'Undefined',
        AllocationGroupBy.status => r.state.label,
      };
}

/// One selectable period under "Validity Start" — months, quarters, years,
/// like the Odoo date-field filter. Matches on the allocation's start date.
class ValidityStartOption {
  const ValidityStartOption({
    required this.key,
    required this.label,
    required this.start,
    required this.end,
  });

  final String key;
  final String label;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime? date) {
    if (date == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  static List<ValidityStartOption> buildOptions(DateTime now) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    final options = <ValidityStartOption>[];

    // Current month and the two before it (Odoo shows the last 3 months).
    for (var i = 0; i < 3; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
      final sameYear = monthStart.year == now.year;
      options.add(ValidityStartOption(
        key: 'month-${monthStart.year}-${monthStart.month}',
        label: sameYear
            ? monthNames[monthStart.month - 1]
            : '${monthNames[monthStart.month - 1]} ${monthStart.year}',
        start: monthStart,
        end: monthEnd,
      ));
    }

    // Quarters of the current year.
    for (var q = 1; q <= 4; q++) {
      final start = DateTime(now.year, (q - 1) * 3 + 1, 1);
      final end = DateTime(now.year, q * 3 + 1, 0);
      options.add(ValidityStartOption(
        key: 'quarter-${now.year}-$q',
        label: 'Q$q ${now.year}',
        start: start,
        end: end,
      ));
    }

    // Current year and the two before it.
    for (var i = 0; i < 3; i++) {
      final year = now.year - i;
      options.add(ValidityStartOption(
        key: 'year-$year',
        label: '$year',
        start: DateTime(year, 1, 1),
        end: DateTime(year, 12, 31),
      ));
    }

    return options;
  }
}

/// A row in the (possibly grouped) allocation list: either a group header
/// or a data record.
class AllocationListEntry {
  const AllocationListEntry.header({
    required this.level,
    required String this.label,
    required int this.count,
  }) : record = null;

  const AllocationListEntry.row(LeaveAllocationRecord this.record)
      : level = 0,
        label = null,
        count = null;

  final int level;
  final String? label;
  final int? count;
  final LeaveAllocationRecord? record;

  bool get isHeader => record == null;
}
