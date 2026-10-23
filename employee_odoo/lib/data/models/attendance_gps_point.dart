import 'package:uuid/uuid.dart';

/// A single GPS sample recorded between attendance check-in and check-out.
///
/// Maps to the Odoo `hr.attendance.gps.point` model (`hr_attendance_gps`).
///
/// ---------------------------------------------------------------------------
/// FIELD NAME CONTRACT — this is what was broken.
///
/// READING (`search_read`): the model has **no** `recorded_at` and **no**
/// `speed` column. The real ones are:
///     recorded_at -> browser_timestamp (device clock, = travel order)
///                    server_timestamp  (upload clock, fallback only)
///     speed       -> calculated_speed  (server-derived, trustworthy)
///                    speed_from_device (chip Doppler, often 0 or -1)
/// Asking for `recorded_at` is what raised
/// `ValueError: Invalid field 'recorded_at' on model 'hr.attendance.gps.point'`.
///
/// WRITING (`record_gps_points`): the addon reads the timestamp from
/// `point_time` **or** `timestamp` — never from `recorded_at`. Sending
/// `recorded_at` meant `browser_timestamp` came back empty, so every single
/// point was rejected with `missing_timestamp`; and since `gps_store_rejected`
/// defaults to False, nothing was written to the table at all. That is why the
/// route was empty even before the read crashed.
///
/// The timestamp is sent as **epoch milliseconds (int)**, not as a string.
/// The addon accepts both, but its batch pre-sort does
/// `float(payload["timestamp"])`, which returns None for a date string — so a
/// whole batch collapses to one sort key and gets ordered by UUID instead of by
/// time, scrambling `sequence`, `distance_from_previous` and
/// `calculated_speed`. An int sorts correctly and needs no server change.
/// ---------------------------------------------------------------------------
class AttendanceGpsPoint {
  AttendanceGpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.sequence = 0,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.attendanceId,
    this.eventType = movement,
    this.validationStatus,
    String? uuid,
  }) : uuid = uuid ?? _uuidGen.v4();

  static const Uuid _uuidGen = Uuid();

  // Event types the addon accepts. `check_in` / `check_out` are privileged:
  // `_validate_payload` lets them through the duplicate / no_movement /
  // too_frequent filters, so the two coordinates the attendance is actually
  // about are never dropped.
  static const String checkIn = 'check_in';
  static const String movement = 'movement';
  static const String stationary = 'stationary';
  static const String checkOut = 'check_out';

  final double latitude;
  final double longitude;

  /// Device time the point was captured.
  final DateTime timestamp;
  final int sequence;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final int? attendanceId;

  final String eventType;

  /// Server verdict; only present on records read back from Odoo.
  /// `accepted` | `suspicious` | `rejected`.
  final String? validationStatus;

  /// Stable client id, so a retried flush cannot create the point twice.
  /// Without one the addon synthesises `legacy-{attendance}-{index}-{lat}-{lon}`
  /// from the **position in the batch** — and the index restarts on every
  /// 60 s flush, so genuine points collide and get swallowed as duplicates.
  final String uuid;

  bool get isEndpoint => eventType == checkIn || eventType == checkOut;

  AttendanceGpsPoint copyWith({String? eventType, int? sequence}) {
    return AttendanceGpsPoint(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      sequence: sequence ?? this.sequence,
      accuracy: accuracy,
      altitude: altitude,
      speed: speed,
      heading: heading,
      attendanceId: attendanceId,
      eventType: eventType ?? this.eventType,
      validationStatus: validationStatus,
      uuid: uuid,
    );
  }

  /// Payload for `record_gps_points` / `/hr_attendance_gps/push_points`.
  ///
  /// [offline] tells the server the fix sat in a queue before it was uploaded.
  /// Without it the `stale_position` check refuses anything older than
  /// `max_position_age` (120 s by default), which silently deletes the whole
  /// backlog after a connectivity drop.
  Map<String, dynamic> toOdoo({bool offline = false}) => {
    'latitude': latitude,
    'longitude': longitude,
    // Never send a negative accuracy: `accuracy <= 0` is flagged
    // `accuracy_missing` (suspicious), and geolocator reports -1 on some
    // emulators and mock providers.
    'accuracy': (accuracy != null && accuracy! > 0) ? accuracy : 0.0,
    'altitude': altitude ?? 0.0,
    'heading': (heading != null && heading! >= 0) ? heading : 0.0,
    'speed': (speed != null && speed! >= 0) ? speed : 0.0,
    // int, deliberately — see the class docstring.
    'timestamp': timestamp.toUtc().millisecondsSinceEpoch,
    'event_type': eventType,
    'uuid': uuid,
    'offline': offline,
  };

  /// Compact JSON for the local disk buffer.
  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'ts': timestamp.toUtc().toIso8601String(),
    'seq': sequence,
    'acc': accuracy,
    'alt': altitude,
    'spd': speed,
    'hdg': heading,
    'evt': eventType,
    'uid': uuid,
    if (attendanceId != null) 'aid': attendanceId,
  };

  factory AttendanceGpsPoint.fromJson(Map<String, dynamic> json) {
    return AttendanceGpsPoint(
      latitude: (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.tryParse(json['ts'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      sequence: (json['seq'] as num?)?.toInt() ?? 0,
      accuracy: (json['acc'] as num?)?.toDouble(),
      altitude: (json['alt'] as num?)?.toDouble(),
      speed: (json['spd'] as num?)?.toDouble(),
      heading: (json['hdg'] as num?)?.toDouble(),
      eventType: json['evt'] as String? ?? movement,
      // Buffers written by the old build have no uuid; minting one is safe
      // because those points were never successfully uploaded anyway.
      uuid: json['uid'] as String?,
      attendanceId: (json['aid'] as num?)?.toInt(),
    );
  }

  factory AttendanceGpsPoint.fromOdoo(Map<String, dynamic> json) {
    return AttendanceGpsPoint(
      attendanceId: _m2oId(json['attendance_id']),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      accuracy: _toDoubleOrNull(json['accuracy']),
      altitude: _toDoubleOrNull(json['altitude']),
      heading: _toDoubleOrNull(json['heading']),
      speed: _toDoubleOrNull(json['calculated_speed']) ??
          _toDoubleOrNull(json['speed_from_device']),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      eventType: _toStringOrNull(json['event_type']) ?? movement,
      validationStatus: _toStringOrNull(json['validation_status']),
      timestamp: _parseOdooUtc(json['browser_timestamp']) ??
          _parseOdooUtc(json['server_timestamp']) ??
          DateTime.now(),
    );
  }

  /// Route payload shape returned by `hr.attendance.get_gps_route()`
  /// (`{lat, lng, time, accuracy, status, event_type, ...}` — note `lat`/`lng`,
  /// not `latitude`/`longitude`).
  factory AttendanceGpsPoint.fromRoutePayload(Map<String, dynamic> json) {
    return AttendanceGpsPoint(
      latitude: _toDouble(json['lat']),
      longitude: _toDouble(json['lng']),
      accuracy: _toDoubleOrNull(json['accuracy']),
      altitude: _toDoubleOrNull(json['altitude']),
      heading: _toDoubleOrNull(json['heading']),
      speed: _toDoubleOrNull(json['speed']) ??
          _toDoubleOrNull(json['device_speed']),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      eventType: _toStringOrNull(json['event_type']) ?? movement,
      validationStatus: _toStringOrNull(json['status']),
      timestamp: _parseOdooUtc(json['time']) ??
          _parseOdooUtc(json['server_time']) ??
          DateTime.now(),
    );
  }

  /// Odoo serialises datetimes as naive UTC (`2026-07-24 06:12:03`).
  /// Parsing that without forcing UTC silently shifts the whole route by the
  /// device's offset.
  static DateTime? _parseOdooUtc(dynamic value) {
    if (value == false || value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is! String) return null;
    var raw = value.trim();
    if (raw.isEmpty) return null;
    if (!raw.contains('T')) raw = raw.replaceFirst(' ', 'T');
    final hasZone =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
    if (!hasZone) raw = '${raw}Z';
    return DateTime.tryParse(raw)?.toLocal();
  }

  static int? _m2oId(dynamic value) {
    if (value is List && value.isNotEmpty) return value[0] as int?;
    if (value is int) return value;
    return null;
  }

  static String? _toStringOrNull(dynamic value) {
    if (value == false || value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double _toDouble(dynamic value) => value is num ? value.toDouble() : 0;

  static double? _toDoubleOrNull(dynamic value) {
    if (value == false || value == null) return null;
    if (value is num) return value.toDouble();
    return null;
  }
}