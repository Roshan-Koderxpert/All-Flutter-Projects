import '../models/attendance_record.dart';
import '../../core/utils/odoo_datetime.dart';
import '../../modules/attendance/models/attendance_search_models.dart';

class AttendanceGrouper {
  AttendanceGrouper._();

  static List<AttendanceMonthGroup> build(
    List<AttendanceRecord> records, {
    AttendanceGroupByField? groupByField,
    AttendanceDateGroupGranularity dateGranularity =
        AttendanceDateGroupGranularity.month,
    String fallbackEmployeeName = 'Employee',
  }) {
    if (records.isEmpty) return [];

    if (groupByField != null) {
      return switch (groupByField) {
        AttendanceGroupByField.employee =>
          _groupByEmployee(records, fallbackEmployeeName),
        AttendanceGroupByField.department => _groupByField(
            records,
            (r) =>
                r.departmentName.isNotEmpty ? r.departmentName : 'No Department',
            fallbackEmployeeName,
          ),
        AttendanceGroupByField.manager => _groupByField(
            records,
            (r) => r.managerName.isNotEmpty ? r.managerName : 'No Manager',
            fallbackEmployeeName,
          ),
        AttendanceGroupByField.method => _groupByField(
            records,
            (r) => r.methodLabel,
            fallbackEmployeeName,
          ),
      };
    }

    return _groupByDateGranularity(
      records,
      dateGranularity,
      fallbackEmployeeName,
    );
  }

  static String groupByPathLabel({
    AttendanceGroupByField? groupByField,
    AttendanceDateGroupGranularity dateGranularity =
        AttendanceDateGroupGranularity.month,
  }) {
    if (groupByField != null) {
      return groupByField.label;
    }
    return 'Date: ${dateGranularity.label} › Employee';
  }

  static List<AttendanceMonthGroup> _groupByDateGranularity(
    List<AttendanceRecord> records,
    AttendanceDateGroupGranularity granularity,
    String fallbackEmployeeName,
  ) {
    final keyFn = switch (granularity) {
      AttendanceDateGroupGranularity.year => (AttendanceRecord r) =>
          '${r.checkIn.year}',
      AttendanceDateGroupGranularity.quarter => (AttendanceRecord r) {
          final q = ((r.checkIn.month - 1) ~/ 3) + 1;
          return 'Q$q ${r.checkIn.year}';
        },
      AttendanceDateGroupGranularity.month => (AttendanceRecord r) =>
          OdooDateTime.formatMonthKey(r.checkIn),
      AttendanceDateGroupGranularity.week => (AttendanceRecord r) {
          final week = _isoWeekNumber(r.checkIn);
          return 'W${week.toString().padLeft(2, '0')} ${r.checkIn.year}';
        },
      AttendanceDateGroupGranularity.day => (AttendanceRecord r) =>
          '${r.checkIn.year}-${r.checkIn.month.toString().padLeft(2, '0')}-${r.checkIn.day.toString().padLeft(2, '0')}',
    };

    final labelFn = switch (granularity) {
      AttendanceDateGroupGranularity.year => (AttendanceRecord r) =>
          '${r.checkIn.year}',
      AttendanceDateGroupGranularity.quarter => (AttendanceRecord r) {
          final q = ((r.checkIn.month - 1) ~/ 3) + 1;
          return 'Q$q ${r.checkIn.year}';
        },
      AttendanceDateGroupGranularity.month => (AttendanceRecord r) =>
          OdooDateTime.formatDate(r.checkIn),
      AttendanceDateGroupGranularity.week => (AttendanceRecord r) {
          final week = _isoWeekNumber(r.checkIn);
          return 'Week ${week.toString().padLeft(2, '0')}, ${r.checkIn.year}';
        },
      AttendanceDateGroupGranularity.day => (AttendanceRecord r) {
          final d = r.checkIn;
          const months = [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December',
          ];
          return '${months[d.month - 1]} ${d.day}, ${d.year}';
        },
    };

    final byKey = <String, List<AttendanceRecord>>{};
    for (final r in records) {
      final key = keyFn(r);
      byKey.putIfAbsent(key, () => []).add(r);
    }

    final keys = byKey.keys.toList()..sort((a, b) => b.compareTo(a));

    return keys.map((key) {
      final list = byKey[key]!..sort((a, b) => b.checkIn.compareTo(a.checkIn));
      final sample = list.first;
      final byEmployee = <int, List<AttendanceRecord>>{};
      for (final r in list) {
        final eid = r.employeeId ?? 0;
        byEmployee.putIfAbsent(eid, () => []).add(r);
      }
      return AttendanceMonthGroup(
        monthKey: key,
        monthLabel: labelFn(sample),
        employees: _employeeGroupsFromMap(byEmployee, fallbackEmployeeName),
      );
    }).toList();
  }

  static int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
    final firstThursday = DateTime(thursday.year, 1, 4);
    return 1 +
        ((thursday.difference(firstThursday).inDays) / 7).floor();
  }

  static List<AttendanceMonthGroup> groupByMonthThenEmployee(
    List<AttendanceRecord> records, {
    String fallbackEmployeeName = 'Employee',
  }) {
    return _groupByDateGranularity(
      records,
      AttendanceDateGroupGranularity.month,
      fallbackEmployeeName,
    );
  }

  static List<AttendanceMonthGroup> _groupByEmployee(
    List<AttendanceRecord> records,
    String fallbackEmployeeName,
  ) {
    final byEmployee = <int, List<AttendanceRecord>>{};
    for (final r in records) {
      final eid = r.employeeId ?? 0;
      byEmployee.putIfAbsent(eid, () => []).add(r);
    }

    final keys = byEmployee.keys.toList()
      ..sort((a, b) {
        final na = byEmployee[a]!.first.employeeName;
        final nb = byEmployee[b]!.first.employeeName;
        return na.compareTo(nb);
      });

    return keys.map((eid) {
      final list = byEmployee[eid]!
        ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
      final name = list.first.employeeName.isNotEmpty
          ? list.first.employeeName
          : fallbackEmployeeName;
      return AttendanceMonthGroup(
        monthKey: 'emp_$eid',
        monthLabel: name,
        employees: [
          AttendanceEmployeeGroup(
            employeeId: eid,
            employeeName: name,
            records: list,
          ),
        ],
      );
    }).toList();
  }

  static List<AttendanceMonthGroup> _groupByField(
    List<AttendanceRecord> records,
    String Function(AttendanceRecord) fieldLabel,
    String fallbackEmployeeName,
  ) {
    final byField = <String, List<AttendanceRecord>>{};
    for (final r in records) {
      final key = fieldLabel(r);
      byField.putIfAbsent(key, () => []).add(r);
    }

    final keys = byField.keys.toList()..sort();

    return keys.map((fieldKey) {
      final list = byField[fieldKey]!
        ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
      final byEmployee = <int, List<AttendanceRecord>>{};
      for (final r in list) {
        final eid = r.employeeId ?? 0;
        byEmployee.putIfAbsent(eid, () => []).add(r);
      }
      return AttendanceMonthGroup(
        monthKey: 'field_$fieldKey',
        monthLabel: fieldKey,
        employees: _employeeGroupsFromMap(byEmployee, fallbackEmployeeName),
      );
    }).toList();
  }

  static List<AttendanceEmployeeGroup> _employeeGroupsFromMap(
    Map<int, List<AttendanceRecord>> byEmployee,
    String fallbackEmployeeName,
  ) {
    return byEmployee.entries.map((entry) {
      final list = entry.value..sort((a, b) => b.checkIn.compareTo(a.checkIn));
      final name = list.first.employeeName.isNotEmpty
          ? list.first.employeeName
          : fallbackEmployeeName;
      return AttendanceEmployeeGroup(
        employeeId: entry.key,
        employeeName: name,
        records: list,
      );
    }).toList()
      ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
  }
}
