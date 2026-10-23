import '../../core/utils/odoo_datetime.dart';

/// How a leave type lets employees take time off — admin-configured per type
/// in Odoo ("Take Time Off in": Day / Half Day / Hours).
enum LeaveRequestUnit { day, halfDay, hour }

LeaveRequestUnit leaveRequestUnitFromOdoo(dynamic value) {
  return switch (value?.toString()) {
    'half_day' || 'half' => LeaveRequestUnit.halfDay,
    'hour' => LeaveRequestUnit.hour,
    _ => LeaveRequestUnit.day,
  };
}

/// Which half of the day a half-day request covers.
enum HalfDayPeriod { morning, afternoon }

extension HalfDayPeriodX on HalfDayPeriod {
  String get odooValue =>
      this == HalfDayPeriod.morning ? 'am' : 'pm';

  String get label =>
      this == HalfDayPeriod.morning ? 'Morning' : 'Afternoon';
}

enum LeaveState {
  draft,
  toApprove,
  secondApproval,
  approved,
  refused,
  cancelled,
  unknown,
}

extension LeaveStateX on LeaveState {
  String get label => switch (this) {
        LeaveState.draft => 'Draft',
        LeaveState.toApprove => 'To Approve',
        LeaveState.secondApproval => 'Second Approval',
        LeaveState.approved => 'Approved',
        LeaveState.refused => 'Refused',
        LeaveState.cancelled => 'Cancelled',
        LeaveState.unknown => 'Unknown',
      };

  bool get isPending =>
      this == LeaveState.toApprove || this == LeaveState.secondApproval;
}

class LeaveRecord {
  LeaveRecord({
    required this.id,
    required this.leaveTypeName,
    this.leaveTypeId,
    this.employeeId,
    this.employeeName = '',
    required this.dateFrom,
    required this.dateTo,
    required this.numberOfDays,
    required this.state,
    this.description = '',
    this.createDate,
  });

  final int id;
  final String leaveTypeName;
  final int? leaveTypeId;
  final int? employeeId;
  final String employeeName;
  final DateTime dateFrom;
  final DateTime dateTo;
  final double numberOfDays;
  final LeaveState state;
  final String description;
  final DateTime? createDate;

  String get dateRangeLabel {
    final from = _formatShort(dateFrom);
    final to = _formatShort(dateTo);
    if (from == to) return from;
    return '$from → $to';
  }

  String get durationLabel =>
      '${numberOfDays.toStringAsFixed(numberOfDays.truncateToDouble() == numberOfDays ? 0 : 1)} day${numberOfDays == 1 ? '' : 's'}';

  /// Odoo treats leave as past when [dateFrom] is before today (local calendar day).
  bool get isStartTodayOrFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    return !start.isBefore(today);
  }

  /// Employee cancel/delete rules aligned with Odoo `hr.leave`:
  /// - Pending requests (`draft`, `confirm`, `validate1`): delete via unlink
  /// - Approved/refused: cancel via `_action_user_cancel`
  /// - Past requests (`date_from < today`): not cancellable by employees
  bool get isCancellableByEmployee {
    if (!isStartTodayOrFuture) return false;
    return switch (state) {
      LeaveState.draft ||
      LeaveState.toApprove ||
      LeaveState.secondApproval ||
      LeaveState.approved ||
      LeaveState.refused =>
        true,
      _ => false,
    };
  }

  String _formatShort(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  factory LeaveRecord.fromOdoo(Map<String, dynamic> json) {
    final dateFrom = _leaveCalendarDate(
      json,
      requestField: 'request_date_from',
      dateTimeField: 'date_from',
    );
    final dateTo = _leaveCalendarDate(
      json,
      requestField: 'request_date_to',
      dateTimeField: 'date_to',
    );

    final type = json['holiday_status_id'];
    var typeName = 'Leave';
    int? typeId;
    if (type is List && type.isNotEmpty) {
      typeId = type[0] as int?;
      if (type.length > 1) typeName = type[1].toString();
    }

    final employee = json['employee_id'];
    var employeeName = '';
    int? employeeIdParsed;
    if (employee is List && employee.isNotEmpty) {
      employeeIdParsed = employee[0] as int?;
      if (employee.length > 1) employeeName = employee[1].toString();
    }

    return LeaveRecord(
      id: json['id'] as int,
      leaveTypeName: typeName,
      leaveTypeId: typeId,
      employeeId: employeeIdParsed,
      employeeName: employeeName,
      dateFrom: dateFrom,
      dateTo: dateTo,
      numberOfDays: _toDouble(json['number_of_days']),
      state: _parseState(json['state']),
      description: _stringField(json['name']),
      createDate: OdooDateTime.parse(json['create_date']),
    );
  }

  /// Prefer Odoo Date fields; fall back to datetime as a local calendar day.
  static DateTime _leaveCalendarDate(
    Map<String, dynamic> json, {
    required String requestField,
    required String dateTimeField,
  }) {
    return OdooDateTime.parseDate(json[requestField]) ??
        OdooDateTime.parseDate(json[dateTimeField]) ??
        _toLocalDateOnly(OdooDateTime.parse(json[dateTimeField])) ??
        DateTime.now();
  }

  static DateTime? _toLocalDateOnly(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static LeaveState _parseState(dynamic value) {
    final raw = _stringField(value).toLowerCase();
    return switch (raw) {
      'draft' => LeaveState.draft,
      'confirm' => LeaveState.toApprove,
      'validate1' => LeaveState.secondApproval,
      'validate' => LeaveState.approved,
      'refuse' || 'refused' => LeaveState.refused,
      'cancel' || 'cancelled' => LeaveState.cancelled,
      _ => LeaveState.unknown,
    };
  }

  static String _stringField(dynamic value) {
    if (value == false || value == null) return '';
    return value.toString();
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }
}

/// A file the user picked to upload with a leave request.
class LeaveAttachmentUpload {
  const LeaveAttachmentUpload({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}

/// A supporting document already stored on a leave request in Odoo.
class LeaveAttachment {
  const LeaveAttachment({
    required this.id,
    required this.name,
    required this.mimetype,
    required this.leaveId,
  });

  final int id;
  final String name;
  final String mimetype;
  final int leaveId;
}

class LeaveTypeOption {
  LeaveTypeOption({
    required this.id,
    required this.name,
    this.remainingDays,
    this.requiresAllocation = true,
    this.requestUnit = LeaveRequestUnit.day,
    this.supportsDocument = false,
  });

  final int id;
  final String name;
  final double? remainingDays;
  final bool requiresAllocation;
  final LeaveRequestUnit requestUnit;
  final bool supportsDocument;

  String get remainingLabel {
    if (remainingDays == null) return name;
    return '$name (${remainingDays!.toStringAsFixed(1)} days left)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaveTypeOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
