/// Preset filters matching Odoo Attendances search panel.
enum AttendancePresetFilter {
  myAttendances,
  myTeam,
  atWork,
  errors,
  autoCheckedOut,
  activeEmployees,
  archivedEmployees,
}

extension AttendancePresetFilterX on AttendancePresetFilter {
  String get label => switch (this) {
        AttendancePresetFilter.myAttendances => 'My Attendances',
        AttendancePresetFilter.myTeam => 'My Team',
        AttendancePresetFilter.atWork => 'At Work',
        AttendancePresetFilter.errors => 'Errors',
        AttendancePresetFilter.autoCheckedOut => 'Automatically Checked-Out',
        AttendancePresetFilter.activeEmployees => 'Active Employees',
        AttendancePresetFilter.archivedEmployees => 'Archived Employees',
      };
}

enum AttendanceGroupByField {
  employee,
  department,
  manager,
  method,
}

extension AttendanceGroupByFieldX on AttendanceGroupByField {
  String get label => switch (this) {
        AttendanceGroupByField.employee => 'Employee',
        AttendanceGroupByField.department => 'Departement',
        AttendanceGroupByField.manager => 'Manager',
        AttendanceGroupByField.method => 'Method',
      };
}

enum AttendanceDateGroupGranularity {
  year,
  quarter,
  month,
  week,
  day,
}

extension AttendanceDateGroupGranularityX on AttendanceDateGroupGranularity {
  String get label => switch (this) {
        AttendanceDateGroupGranularity.year => 'Year',
        AttendanceDateGroupGranularity.quarter => 'Quarter',
        AttendanceDateGroupGranularity.month => 'Month',
        AttendanceDateGroupGranularity.week => 'Week',
        AttendanceDateGroupGranularity.day => 'Day',
      };
}

/// Selected date filter from Filters › Date submenu.
class AttendanceDateFilterSelection {
  AttendanceDateFilterSelection({
    required this.label,
    required this.from,
    required this.to,
  });

  final String label;
  final DateTime from;
  final DateTime to;
}

/// Chip shown inside the Odoo-style search bar.
class AttendanceSearchChip {
  AttendanceSearchChip({
    required this.label,
    required this.kind,
    this.filter,
    this.groupByField,
    this.dateGranularity,
    this.dateFilter,
  });

  final String label;
  final String kind; // 'filter' | 'groupBy' | 'dateFilter'
  final AttendancePresetFilter? filter;
  final AttendanceGroupByField? groupByField;
  final AttendanceDateGroupGranularity? dateGranularity;
  final AttendanceDateFilterSelection? dateFilter;
}
