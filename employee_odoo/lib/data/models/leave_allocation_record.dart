import '../../core/utils/odoo_datetime.dart';

class LeaveAllocationRecord {
  LeaveAllocationRecord({
    required this.id,
    required this.employeeName,
    this.employeeId,
    required this.leaveTypeName,
    this.leaveTypeId,
    required this.numberOfDays,
    this.allocationType = '',
    this.rawAllocationType = '',
    this.accrualPlanName = '',
    required this.state,
    this.description = '',
    this.nameValidity,
    this.dateFrom,
    this.dateTo,
  });

  final int id;
  final String employeeName;
  final int? employeeId;
  final String leaveTypeName;
  final int? leaveTypeId;
  final double numberOfDays;
  final String allocationType;
  final String rawAllocationType;
  final String accrualPlanName;
  final LeaveAllocationState state;
  final String description;
  final String? nameValidity;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  String get _safeNameValidity => nameValidity ?? '';

  String get amountLabel =>
      '${numberOfDays.toStringAsFixed(numberOfDays.truncateToDouble() == numberOfDays ? 0 : 1)} days';

  String get allocationAmountValue => numberOfDays.toStringAsFixed(2);

  bool get isAccrualAllocation =>
      rawAllocationType == 'accrual' ||
      allocationType.toLowerCase().contains('accrual');

  bool get canApproveOrRefuse => canApprove;

  bool get canApprove =>
      state == LeaveAllocationState.toApprove ||
      state == LeaveAllocationState.secondApproval;

  bool get canRefuse => canApprove;

  String get detailTitle {
    if (description.trim().isNotEmpty) return description.trim();
    if (employeeName.isNotEmpty) {
      return '$leaveTypeName for $employeeName';
    }
    return leaveTypeName;
  }

  String get validityPeriodLabel {
    final start = dateFrom != null
        ? OdooDateTime.formatDateSlash(dateFrom)
        : null;
    final end =
        dateTo != null ? OdooDateTime.formatDateSlash(dateTo) : null;

    if (start != null && end != null) return '$start → $end';
    if (start != null) return '$start → No Limit';
    if (end != null) return end;

    final fromName = _validityFromNameValidity(_safeNameValidity);
    if (fromName != null) return fromName;

    return '—';
  }

  static String? _validityFromNameValidity(String raw) {
    if (raw.isEmpty) return null;

    final range = RegExp(
      r'\(from\s+(.+?)\s+to\s+(.+?)\)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (range != null) {
      return '${range.group(1)} → ${range.group(2)}';
    }

    final openEnded = RegExp(
      r'\(from\s+(.+?)\s+to\s+No Limit\)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (openEnded != null) {
      return '${openEnded.group(1)} → No Limit';
    }

    return null;
  }

  static DateTime? _parseAllocationDate(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final parsed = OdooDateTime.parseDate(json[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  factory LeaveAllocationRecord.fromOdoo(Map<String, dynamic> json) {
    final employee = json['employee_id'];
    var employeeName = '';
    int? employeeId;
    if (employee is List && employee.isNotEmpty) {
      employeeId = employee[0] as int?;
      if (employee.length > 1) employeeName = employee[1].toString();
    }

    final leaveType = json['holiday_status_id'];
    var leaveTypeName = 'Leave';
    int? leaveTypeId;
    if (leaveType is List && leaveType.isNotEmpty) {
      leaveTypeId = leaveType[0] as int?;
      if (leaveType.length > 1) leaveTypeName = leaveType[1].toString();
    }

    final accrual = json['accrual_plan_id'];
    var accrualPlanName = '';
    if (accrual is List && accrual.length > 1) {
      accrualPlanName = accrual[1].toString();
    } else if (accrual is String && accrual.isNotEmpty) {
      accrualPlanName = accrual;
    }

    var allocType = _stringField(json['allocation_type']);
    if (allocType.isEmpty) {
      allocType = _stringField(json['holiday_type']);
    }

    return LeaveAllocationRecord(
      id: json['id'] as int,
      employeeName: employeeName,
      employeeId: employeeId,
      leaveTypeName: leaveTypeName,
      leaveTypeId: leaveTypeId,
      numberOfDays: _toDouble(json['number_of_days']),
      allocationType: _formatAllocationType(allocType),
      rawAllocationType: allocType,
      accrualPlanName: accrualPlanName.isNotEmpty ? accrualPlanName : '—',
      state: LeaveAllocationState.fromOdoo(json['state']),
      description: _stringField(json['name']),
      nameValidity: _optionalStringField(json['name_validity']),
      dateFrom: _parseAllocationDate(json, ['date_from', 'request_date_from']),
      dateTo: _parseAllocationDate(json, ['date_to', 'request_date_to']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  static String _stringField(dynamic value) {
    if (value == false || value == null) return '';
    return value.toString();
  }

  static String? _optionalStringField(dynamic value) {
    if (value == false || value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _formatAllocationType(String raw) {
    if (raw.isEmpty) return '—';
    if (raw == 'regular') return 'Regular';
    if (raw == 'accrual') return 'Accrual';
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

enum LeaveAllocationState {
  draft,
  toApprove,
  secondApproval,
  approved,
  refused,
  cancelled,
  unknown;

  String get label => switch (this) {
        LeaveAllocationState.draft => 'Draft',
        LeaveAllocationState.toApprove => 'To Approve',
        LeaveAllocationState.secondApproval => 'Second Approval',
        LeaveAllocationState.approved => 'Approved',
        LeaveAllocationState.refused => 'Refused',
        LeaveAllocationState.cancelled => 'Cancelled',
        LeaveAllocationState.unknown => 'Unknown',
      };

  static LeaveAllocationState fromOdoo(dynamic value) {
    final raw = _odooString(value).toLowerCase();
    return switch (raw) {
      'draft' => LeaveAllocationState.draft,
      'confirm' => LeaveAllocationState.toApprove,
      'validate1' => LeaveAllocationState.secondApproval,
      'validate' => LeaveAllocationState.approved,
      'refuse' || 'refused' => LeaveAllocationState.refused,
      'cancel' || 'cancelled' => LeaveAllocationState.cancelled,
      _ => LeaveAllocationState.unknown,
    };
  }

  static String _odooString(dynamic value) {
    if (value == false || value == null) return '';
    return value.toString();
  }
}
