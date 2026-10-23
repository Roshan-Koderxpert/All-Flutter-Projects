import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Mirror of `/hr_attendance_gps/config`.
///
/// Key names now follow the addon's `_gps_tracking_config()` exactly:
/// `capture_interval` / `idle_interval` (seconds), `min_distance`,
/// `max_accuracy`, `road_routing`, plus the fixed tuning the controller sends
/// so the app and server can never disagree about a threshold.
///
/// The old `min_save_interval` / `max_save_interval` names are gone — reading
/// them returned null and the sampler silently fell back to hard-coded values
/// that no longer matched the server.
class AttendanceGpsConfig {
  const AttendanceGpsConfig({
    this.enabled = true,
    this.routeEnabled = true,
    this.roadRouting = false,
    this.locationRequired = false,
    this.captureInterval = 30,
    this.idleInterval = 300,
    this.minDistance = 10,
    this.duplicateDistance = 5,
    this.preferredAccuracy = 25,
    this.maxAccuracy = 50,
    this.highAccuracy = true,
    this.maxPositionAge = 120,
    this.endpointSampleSeconds = 10,
    this.positionTimeoutMs = 20000,
    this.retryCount = 3,
    this.offlineEnabled = true,
    this.offlineBatchSize = 50,
    this.offlineMaxRetries = 6,
    this.flushMs = 180000,
    this.pollMs = 300000,
    this.consentRequired = false,
    this.consentMessage = '',
    this.checkedIn = false,
    this.attendanceId,
    this.sessionId,
  });

  final bool enabled;

  /// Continuous route tracking between the two endpoints.
  final bool routeEnabled;

  /// Server-side road snapping is on. When true the app must draw the server's
  /// `road.segments` and NOT map-match locally.
  final bool roadRouting;

  final bool locationRequired;

  /// Seconds between samples while moving. (Server key: `capture_interval`.)
  final int captureInterval;

  /// Seconds between samples while stationary. (Server key: `idle_interval`.)
  final int idleInterval;

  /// Metres. Below this the fix is treated as no movement.
  final int minDistance;

  /// Metres. Below this two fixes are the same place.
  final int duplicateDistance;

  final int preferredAccuracy;

  /// Metres. A fix vaguer than this is refused server-side.
  final int maxAccuracy;

  final bool highAccuracy;

  /// Seconds. A fix older than this is refused as a cached position.
  final int maxPositionAge;

  final int endpointSampleSeconds;
  final int positionTimeoutMs;
  final int retryCount;
  final bool offlineEnabled;
  final int offlineBatchSize;
  final int offlineMaxRetries;
  final int flushMs;
  final int pollMs;

  final bool consentRequired;
  final String consentMessage;

  final bool checkedIn;
  final int? attendanceId;
  final int? sessionId;

  /// Sampling period, +1 s so a sample is never refused for arriving too soon
  /// (a 15 s timer routinely fires at 14.97 s and the server rejects that as
  /// too frequent).
  Duration get sampleInterval => Duration(seconds: captureInterval + 1);

  /// +1 m over the server floor, same reasoning.
  double get minMoveMeters => minDistance.toDouble() + 1;

  Duration get flushInterval => Duration(milliseconds: flushMs);

  static const AttendanceGpsConfig defaults = AttendanceGpsConfig();

  factory AttendanceGpsConfig.fromJson(Map<String, dynamic> json) {
    int asInt(String key, int fallback) {
      final v = json[key];
      return v is num ? v.toInt() : fallback;
    }

    bool asBool(String key, bool fallback) {
      final v = json[key];
      return v is bool ? v : fallback;
    }

    return AttendanceGpsConfig(
      enabled: asBool('enabled', true),
      routeEnabled: asBool('route_enabled', true),
      roadRouting: asBool('road_routing', false),
      locationRequired: asBool('location_required', false),
      captureInterval: asInt('capture_interval', 30),
      idleInterval: asInt('idle_interval', 300),
      minDistance: asInt('min_distance', 10),
      duplicateDistance: asInt('duplicate_distance', 5),
      preferredAccuracy: asInt('preferred_accuracy', 25),
      maxAccuracy: asInt('max_accuracy', 50),
      highAccuracy: asBool('high_accuracy', true),
      maxPositionAge: asInt('max_position_age', 120),
      endpointSampleSeconds: asInt('endpoint_sample_seconds', 10),
      positionTimeoutMs: asInt('position_timeout_ms', 20000),
      retryCount: asInt('retry_count', 3),
      offlineEnabled: asBool('offline_enabled', true),
      offlineBatchSize: asInt('offline_batch_size', 50),
      offlineMaxRetries: asInt('offline_max_retries', 6),
      flushMs: asInt('flush_ms', 180000),
      pollMs: asInt('poll_ms', 300000),
      consentRequired: asBool('consent_required', false),
      consentMessage: (json['consent_message'] ?? '').toString(),
      checkedIn: asBool('checked_in', false),
      attendanceId: json['attendance_id'] is int ? json['attendance_id'] as int : null,
      sessionId: json['session_id'] is int ? json['session_id'] as int : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'route_enabled': routeEnabled,
    'road_routing': roadRouting,
    'location_required': locationRequired,
    'capture_interval': captureInterval,
    'idle_interval': idleInterval,
    'min_distance': minDistance,
    'duplicate_distance': duplicateDistance,
    'preferred_accuracy': preferredAccuracy,
    'max_accuracy': maxAccuracy,
    'high_accuracy': highAccuracy,
    'max_position_age': maxPositionAge,
    'endpoint_sample_seconds': endpointSampleSeconds,
    'position_timeout_ms': positionTimeoutMs,
    'retry_count': retryCount,
    'offline_enabled': offlineEnabled,
    'offline_batch_size': offlineBatchSize,
    'offline_max_retries': offlineMaxRetries,
    'flush_ms': flushMs,
    'poll_ms': pollMs,
  };

  static const String _key = 'route_gps_server_config';

  Future<void> persist() => FlutterForegroundTask.saveData(
    key: _key,
    value: jsonEncode(toJson()),
  );

  static Future<AttendanceGpsConfig> load() async {
    try {
      final raw = await FlutterForegroundTask.getData<String>(key: _key);
      if (raw == null || raw.isEmpty) return defaults;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AttendanceGpsConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return defaults;
  }

  static Future<void> forget() => FlutterForegroundTask.removeData(key: _key);

  @override
  String toString() =>
      'GpsConfig(capture=${captureInterval}s idle=${idleInterval}s '
          'minDist=${minDistance}m maxAcc=${maxAccuracy}m route=$routeEnabled '
          'roadRouting=$roadRouting)';
}