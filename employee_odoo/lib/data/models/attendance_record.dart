import '../../core/utils/odoo_datetime.dart';

/// Check-in or check-out metadata from Odoo.
class AttendanceEventMeta {
  AttendanceEventMeta({
    this.mode = '',
    this.ipAddress = '',
    this.browser = '',
    this.localisation = '',
    this.latitude,
    this.longitude,
  });

  final String mode;
  final String ipAddress;
  final String browser;
  final String localisation;
  final double? latitude;
  final double? longitude;

  String get modeLabel {
    if (mode.isEmpty) return '—';
    if (mode.length == 1) return mode.toUpperCase();
    return mode[0].toUpperCase() + mode.substring(1);
  }

  String get localisationLabel =>
      localisation.isNotEmpty ? localisation : 'Unknown';

  String get gpsCoordinates {
    if (latitude == null || longitude == null) return '—';
    return '$latitude, $longitude';
  }

  bool get hasGps => latitude != null && longitude != null;

  String? get mapsUrl {
    if (!hasGps) return null;
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }
}

enum AttendanceApprovalStatus {
  toApprove,
  approved,
  refused,
  none,
}

extension AttendanceApprovalStatusX on AttendanceApprovalStatus {
  String get label => switch (this) {
        AttendanceApprovalStatus.toApprove => 'To Approve',
        AttendanceApprovalStatus.approved => 'Approved',
        AttendanceApprovalStatus.refused => 'Refused',
        AttendanceApprovalStatus.none => '',
      };
}

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.checkIn,
    this.checkOut,
    required this.workedHours,
    this.employeeId,
    this.employeeName = '',
    this.workedExtraHours,
    this.extraHours,
    this.departmentName = '',
    this.managerName = '',
    this.inMode = '',
    this.outMode = '',
    this.employeeActive = true,
    this.approvalStatus = AttendanceApprovalStatus.none,
    AttendanceEventMeta? checkInMeta,
    AttendanceEventMeta? checkOutMeta,
  })  : checkInMeta = checkInMeta ?? AttendanceEventMeta(),
        checkOutMeta = checkOutMeta ?? AttendanceEventMeta();

  final int id;
  final DateTime checkIn;
  final DateTime? checkOut;
  final double workedHours;
  final int? employeeId;
  final String employeeName;
  final double? workedExtraHours;
  final double? extraHours;
  final String departmentName;
  final String managerName;
  final String inMode;
  final String outMode;
  final bool employeeActive;
  final AttendanceApprovalStatus approvalStatus;
  final AttendanceEventMeta checkInMeta;
  final AttendanceEventMeta checkOutMeta;

  String get methodLabel {
    final inL = inMode.isNotEmpty ? inMode : 'manual';
    final outL = outMode.isNotEmpty ? outMode : (isOpen ? '—' : 'manual');
    return '$inL / $outL';
  }

  String get detailTitle {
    final inT = OdooDateTime.formatTime(checkIn);
    final outT = checkOut != null ? OdooDateTime.formatTime(checkOut) : '--:--';
    return '${OdooDateTime.formatDurationHhMm(effectiveWorkedHours)} ($inT-$outT)';
  }

  AttendanceRecord copyWith({
    String? departmentName,
    String? managerName,
    bool? employeeActive,
    String? inMode,
    String? outMode,
    AttendanceApprovalStatus? approvalStatus,
    AttendanceEventMeta? checkInMeta,
    AttendanceEventMeta? checkOutMeta,
    double? workedExtraHours,
    double? extraHours,
  }) {
    return AttendanceRecord(
      id: id,
      checkIn: checkIn,
      checkOut: checkOut,
      workedHours: workedHours,
      employeeId: employeeId,
      employeeName: employeeName,
      workedExtraHours: workedExtraHours ?? this.workedExtraHours,
      extraHours: extraHours ?? this.extraHours,
      departmentName: departmentName ?? this.departmentName,
      managerName: managerName ?? this.managerName,
      inMode: inMode ?? this.inMode,
      outMode: outMode ?? this.outMode,
      employeeActive: employeeActive ?? this.employeeActive,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      checkInMeta: checkInMeta ?? this.checkInMeta,
      checkOutMeta: checkOutMeta ?? this.checkOutMeta,
    );
  }

  bool get isOpen => checkOut == null;

  double get effectiveWorkedHours {
    if (!isOpen) return workedHours;
    final elapsed = DateTime.now().difference(checkIn).inMinutes / 60.0;
    return elapsed > 0 ? elapsed : 0;
  }

  /// Overtime exactly as Odoo computed it.
  ///
  /// This used to fall back to `workedHours - 8` whenever the server sent no
  /// value, which is wrong for anyone whose schedule isn't a plain 8-hour day
  /// and is why the app's figures disagreed with the web client. When Odoo
  /// has no number, the app now reports none rather than inventing one.
  double get effectiveWorkedExtraHours => workedExtraHours ?? 0;

  /// The validated overtime where the server tracks it separately, otherwise
  /// the same computed overtime.
  double get effectiveExtraHours => extraHours ?? effectiveWorkedExtraHours;

  String get checkInLabel => OdooDateTime.formatDateTime(checkIn);

  String get checkOutLabel =>
      checkOut != null ? OdooDateTime.formatDateTime(checkOut) : '--';

  String get workedHoursLabel =>
      OdooDateTime.formatDurationHhMm(effectiveWorkedHours);

  String get workedExtraHoursLabel =>
      OdooDateTime.formatDurationHhMm(effectiveWorkedExtraHours);

  String get extraHoursLabel =>
      OdooDateTime.formatDurationHhMm(effectiveExtraHours);

  AttendanceApprovalStatus get displayApprovalStatus {
    if (approvalStatus != AttendanceApprovalStatus.none) {
      return approvalStatus;
    }
    if (isOpen) return AttendanceApprovalStatus.toApprove;
    return AttendanceApprovalStatus.approved;
  }

  factory AttendanceRecord.fromOdoo(Map<String, dynamic> json) {
    final checkIn = OdooDateTime.parse(json['check_in']);
    if (checkIn == null) {
      throw FormatException('Invalid check_in: ${json['check_in']}');
    }

    final checkOut = OdooDateTime.parse(json['check_out']);
    final hours = _toDouble(json['worked_hours']);

    var empId = json['employee_id'];
    int? employeeIdParsed;
    var employeeName = '';
    if (empId is List && empId.isNotEmpty) {
      employeeIdParsed = empId[0] as int?;
      if (empId.length > 1) employeeName = empId[1].toString();
    }

    return AttendanceRecord(
      id: json['id'] as int,
      checkIn: checkIn,
      checkOut: checkOut,
      workedHours: hours,
      employeeId: employeeIdParsed,
      employeeName: employeeName,
      // `overtime_hours` is what Odoo computes for this attendance;
      // `validated_overtime_hours` is the approved figure where the server
      // keeps one. The older `worked_extra_hours` / `extra_hours` names are
      // still accepted for databases that have them.
      workedExtraHours: _toDoubleOrNull(json['overtime_hours']) ??
          _toDoubleOrNull(json['worked_extra_hours']),
      extraHours: _toDoubleOrNull(json['validated_overtime_hours']) ??
          _toDoubleOrNull(json['extra_hours']) ??
          _toDoubleOrNull(json['overtime_hours']),
      inMode: _stringField(json['in_mode']),
      outMode: _stringField(json['out_mode']),
      approvalStatus: _parseApprovalStatus(json),
      checkInMeta: _parseCheckInMeta(json),
      checkOutMeta: _parseCheckOutMeta(json),
    );
  }

  static AttendanceApprovalStatus _parseApprovalStatus(
    Map<String, dynamic> json,
  ) {
    final raw = _stringField(
      json['overtime_status'] ??
          json['state'] ??
          json['validation_status'],
    ).toLowerCase();

    if (raw == 'to_approve' || raw == 'to approve') {
      return AttendanceApprovalStatus.toApprove;
    }
    if (raw.contains('approve') && !raw.contains('to')) {
      return AttendanceApprovalStatus.approved;
    }
    if (raw == 'refused' || raw == 'reject' || raw == 'rejected') {
      return AttendanceApprovalStatus.refused;
    }
    if (raw == 'approved' || raw == 'validate' || raw == 'confirmed') {
      return AttendanceApprovalStatus.approved;
    }
    return AttendanceApprovalStatus.none;
  }

  static AttendanceEventMeta _parseCheckInMeta(Map<String, dynamic> json) {
    return AttendanceEventMeta(
      mode: _stringField(json['in_mode']),
      ipAddress: _stringField(
        json['in_ip_address'] ?? json['in_ip'] ?? json['check_in_ip'],
      ),
      browser: _stringField(json['in_browser'] ?? json['check_in_browser']),
      localisation: _formatLocalisation(
        city: _stringField(json['in_city']),
        country: _stringField(json['in_country_name']),
      ),
      latitude: _toDoubleOrNull(json['in_latitude']),
      longitude: _toDoubleOrNull(json['in_longitude']),
    );
  }

  static AttendanceEventMeta _parseCheckOutMeta(Map<String, dynamic> json) {
    return AttendanceEventMeta(
      mode: _stringField(json['out_mode']),
      ipAddress: _stringField(
        json['out_ip_address'] ?? json['out_ip'] ?? json['check_out_ip'],
      ),
      browser: _stringField(json['out_browser'] ?? json['check_out_browser']),
      localisation: _formatLocalisation(
        city: _stringField(json['out_city']),
        country: _stringField(json['out_country_name']),
      ),
      latitude: _toDoubleOrNull(json['out_latitude']),
      longitude: _toDoubleOrNull(json['out_longitude']),
    );
  }

  static String _formatLocalisation({
    required String city,
    required String country,
  }) {
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (city.isNotEmpty) return city;
    if (country.isNotEmpty) return country;
    return '';
  }

  static String _stringField(dynamic value) {
    if (value == false || value == null) return '';
    return value.toString();
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value == false || value == null) return null;
    if (value is num) return value.toDouble();
    return null;
  }
}

class AttendanceEmployeeGroup {
  AttendanceEmployeeGroup({
    required this.employeeId,
    required this.employeeName,
    required this.records,
  });

  final int employeeId;
  final String employeeName;
  final List<AttendanceRecord> records;

  int get recordCount => records.length;

  // Totals use Odoo's stored figures and add every record, so a group here
  // shows exactly what the same group shows in the web client. An open
  // attendance contributes its stored hours (0 until check-out), which is how
  // Odoo totals it — the live running time belongs on the Today card, not in
  // a historical total.
  double get totalWorkedHours =>
      records.fold(0.0, (s, r) => s + r.workedHours);

  double get totalWorkedExtraHours =>
      records.fold(0.0, (s, r) => s + r.effectiveWorkedExtraHours);

  double get totalExtraHours =>
      records.fold(0.0, (s, r) => s + r.effectiveExtraHours);
}

class AttendanceMonthGroup {
  AttendanceMonthGroup({
    required this.monthKey,
    required this.monthLabel,
    required this.employees,
  });

  final String monthKey;
  final String monthLabel;
  final List<AttendanceEmployeeGroup> employees;

  int get recordCount =>
      employees.fold(0, (s, e) => s + e.recordCount);

  double get totalWorkedHours =>
      employees.fold(0, (s, e) => s + e.totalWorkedHours);

  double get totalWorkedExtraHours =>
      employees.fold(0.0, (s, e) => s + e.totalWorkedExtraHours);

  double get totalExtraHours =>
      employees.fold(0.0, (s, e) => s + e.totalExtraHours);
}

class TodayAttendanceSummary {
  TodayAttendanceSummary({
    required this.status,
    this.checkIn,
    this.checkOut,
    required this.workedHours,
    this.closedHours = 0,
    this.openRecord,
  });

  final String status;
  final DateTime? checkIn;
  final DateTime? checkOut;

  /// Total at the moment this summary was built. Goes stale while checked in —
  /// use [liveWorkedHours] for anything on screen.
  final double workedHours;

  /// Hours from today's completed sessions only. Fixed, so the running total
  /// can be recomputed at any time without asking the server again.
  final double closedHours;

  final AttendanceRecord? openRecord;

  bool get isCheckedIn => status == 'checked_in';

  /// Today's total right now: finished sessions plus time on the open one.
  ///
  /// Odoo's own tooltip works this way ("Before 18:42" + "Since 18:42"), which
  /// is why a value frozen at fetch time drifted behind the web client.
  double get liveWorkedHours {
    final start = checkIn;
    if (!isCheckedIn || start == null) return workedHours;
    final elapsed = DateTime.now().difference(start).inSeconds / 3600.0;
    return closedHours + (elapsed > 0 ? elapsed : 0);
  }

  factory TodayAttendanceSummary.empty() {
    return TodayAttendanceSummary(
      status: 'not_checked',
      workedHours: 0,
    );
  }
}
