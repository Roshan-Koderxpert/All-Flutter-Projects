import 'package:latlong2/latlong.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../core/utils/api_logger.dart';
import '../models/attendance_gps_config.dart';
import '../models/attendance_gps_point.dart';

class AttendanceGpsUnavailable implements Exception {
  AttendanceGpsUnavailable([this.message = 'GPS route module not installed.']);
  final String message;
  @override
  String toString() => 'AttendanceGpsUnavailable: $message';
}

class AttendanceGpsForbidden implements Exception {
  AttendanceGpsForbidden([
    this.message = 'Route viewing is disabled by your company.',
  ]);
  final String message;
  @override
  String toString() => 'AttendanceGpsForbidden: $message';
}

class GpsRejection {
  const GpsRejection({this.uuid, required this.reason, this.detail = ''});
  final String? uuid;
  final String reason;
  final String detail;
  @override
  String toString() => detail.isEmpty ? reason : '$reason ($detail)';
}

class GpsUploadResult {
  const GpsUploadResult({
    this.stored = 0,
    this.accepted = const [],
    this.suspicious = const [],
    this.rejected = const [],
    this.duplicate = const [],
    this.sessionState = '',
  });

  final int stored;
  final List<String> accepted;
  final List<GpsRejection> suspicious;
  final List<GpsRejection> rejected;
  final List<String> duplicate;
  final String sessionState;

  Map<String, int> get rejectionHistogram {
    final counts = <String, int>{};
    for (final r in rejected) {
      counts[r.reason] = (counts[r.reason] ?? 0) + 1;
    }
    return counts;
  }

  @override
  String toString() => 'stored=$stored accepted=${accepted.length} '
      'suspicious=${suspicious.length} duplicate=${duplicate.length} '
      'rejected=${rejected.length} $rejectionHistogram';
}

/// State of the server-side road snapping. Mirrors `road_route_state`.
enum RoadRouteState { none, queued, done, partial, skipped, failed }

RoadRouteState _roadState(String? s) {
  switch (s) {
    case 'queued':
      return RoadRouteState.queued;
    case 'done':
      return RoadRouteState.done;
    case 'partial':
      return RoadRouteState.partial;
    case 'skipped':
      return RoadRouteState.skipped;
    case 'failed':
      return RoadRouteState.failed;
    default:
      return RoadRouteState.none;
  }
}

/// The road geometry computed by the server (`road` block of get_gps_route).
class RoadRoute {
  const RoadRoute({
    this.state = RoadRouteState.none,
    this.segments = const [],
    this.distanceKm = 0,
    this.thinned = false,
    this.error = '',
    this.errorCode = '',
  });

  /// Each segment is a separate continuous road polyline. More than one means
  /// the server could not join them (a gap, a ferry) — they must be drawn as
  /// separate lines, never bridged.
  final List<List<LatLng>> segments;
  final RoadRouteState state;
  final double distanceKm;
  final bool thinned;
  final String error;
  final String errorCode;

  bool get isReady => state == RoadRouteState.done || state == RoadRouteState.partial;
  bool get isPending => state == RoadRouteState.queued;
  bool get hasGeometry => segments.any((s) => s.length >= 2);
}

class AttendanceRoute {
  const AttendanceRoute({
    this.points = const [],
    this.line = const [],
    this.endpoints = const [],
    this.gaps = const [],
    this.road = const RoadRoute(),
    this.distanceKm = 0,
    this.restricted = false,
    this.simplified = false,
    this.sessionId,
  });

  final List<AttendanceGpsPoint> points;

  /// Raw (unsnapped) polyline from the server, already ordered and simplified.
  final List<LatLng> line;

  final List<AttendanceGpsPoint> endpoints;
  final List<RouteGap> gaps;

  /// Server-snapped road geometry. Prefer this over [line] when ready.
  final RoadRoute road;

  final double distanceKm;
  final bool restricted;
  final bool simplified;
  final int? sessionId;

  bool get isEmpty =>
      points.isEmpty && line.isEmpty && endpoints.isEmpty && !road.hasGeometry;

  LatLng? get checkInLocation =>
      _locate(AttendanceGpsPoint.checkIn) ??
          (points.isNotEmpty
              ? LatLng(points.first.latitude, points.first.longitude)
              : null);

  LatLng? get checkOutLocation =>
      _locate(AttendanceGpsPoint.checkOut) ??
          (points.isNotEmpty
              ? LatLng(points.last.latitude, points.last.longitude)
              : null);

  LatLng? _locate(String eventType) {
    for (final p in points) {
      if (p.eventType == eventType) return LatLng(p.latitude, p.longitude);
    }
    for (final p in endpoints) {
      if (p.eventType == eventType) return LatLng(p.latitude, p.longitude);
    }
    return null;
  }

  bool get endpointsCollapsed {
    final a = checkInLocation;
    final b = checkOutLocation;
    if (a == null || b == null) return true;
    return const Distance()(a, b) < 10;
  }
}

class RouteGap {
  const RouteGap({required this.from, required this.to, required this.seconds});
  final LatLng from;
  final LatLng to;
  final double seconds;
}

class AttendanceGpsRepository {
  AttendanceGpsRepository(this._client);

  final OdooClient _client;

  static const String _attendanceModel = 'hr.attendance';

  Future<AttendanceGpsConfig> fetchConfig() async {
    try {
      final res = await _client.callRPC('/hr_attendance_gps/config', 'call', {});
      if (res is Map) {
        final config =
        AttendanceGpsConfig.fromJson(Map<String, dynamic>.from(res));
        ApiLogger.info('fetchConfig: $config');
        return config;
      }
    } catch (e) {
      ApiLogger.info('fetchConfig failed, using defaults: $e');
    }
    return AttendanceGpsConfig.defaults;
  }

  Future<int?> startSession({
    String? deviceSessionUuid,
    String? deviceInfo,
    bool consent = true,
  }) async {
    try {
      final res = await _client.callRPC(
        '/hr_attendance_gps/start_session',
        'call',
        {
          'entry_point': 'mobile_app',
          'device_session_uuid': deviceSessionUuid,
          'device_info': deviceInfo,
          'consent': consent,
        },
      );
      if (res is Map && res['tracking'] == true) {
        final id = res['session_id'];
        ApiLogger.info('startSession: session=$id');
        return id is int ? id : null;
      }
      ApiLogger.info('startSession declined: ${res is Map ? res['reason'] : res}');
    } catch (e) {
      ApiLogger.info('startSession failed: $e');
    }
    return null;
  }

  /// Store a check-in or check-out endpoint via the dedicated endpoint.
  /// Replaces tagging the first/last background sample.
  Future<void> recordEndpoint({
    required AttendanceGpsPoint point,
    String? deviceSessionUuid,
    String? deviceInfo,
    bool consent = true,
  }) async {
    try {
      await _client.callRPC(
        '/hr_attendance_gps/record_endpoint',
        'call',
        {
          'latitude': point.latitude,
          'longitude': point.longitude,
          'accuracy': (point.accuracy != null && point.accuracy! > 0)
              ? point.accuracy
              : 0.0,
          'event_type': point.eventType,
          'timestamp': point.timestamp.toUtc().millisecondsSinceEpoch,
          'uuid': point.uuid,
          'device_session_uuid': deviceSessionUuid,
          'device_info': deviceInfo,
          'consent': consent,
        },
      );
      ApiLogger.info('recordEndpoint ${point.eventType} stored');
    } catch (e, st) {
      ApiLogger.error('recordEndpoint ${point.eventType} failed', e, st);
    }
  }

  /// Report a missing endpoint fix (permission denied / timeout) so the reason
  /// is stored on the session.
  Future<void> recordEndpointMissing({
    required String eventType,
    required String reason,
  }) async {
    try {
      await _client.callRPC(
        '/hr_attendance_gps/record_endpoint',
        'call',
        {'event_type': eventType, 'missing_reason': reason},
      );
    } catch (_) {}
  }

  Future<GpsUploadResult> pushPoints(
      int sessionId,
      List<AttendanceGpsPoint> points, {
        Duration offlineThreshold = const Duration(seconds: 45),
      }) async {
    if (points.isEmpty) return const GpsUploadResult();
    final ordered = [...points]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final now = DateTime.now();
    final payload = ordered
        .map((p) =>
        p.toOdoo(offline: now.difference(p.timestamp) > offlineThreshold))
        .toList();

    final res = await _client.callRPC(
      '/hr_attendance_gps/push_points',
      'call',
      {'session_id': sessionId, 'points': payload, 'source': 'mobile_app'},
    );
    if (res is! Map) return const GpsUploadResult();
    final result = _parseUpload(Map<String, dynamic>.from(res));
    ApiLogger.info('pushPoints sent=${ordered.length} → $result');
    return result;
  }

  GpsUploadResult _parseUpload(Map<String, dynamic> data) {
    List<GpsRejection> reasons(dynamic raw) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        return GpsRejection(
          uuid: m['uuid'] as String?,
          reason: (m['reason'] ?? 'unknown').toString(),
          detail: (m['detail'] ?? '').toString(),
        );
      }).toList();
    }

    return GpsUploadResult(
      stored: (data['stored'] as num?)?.toInt() ?? 0,
      accepted:
      ((data['accepted'] as List?) ?? const []).whereType<String>().toList(),
      suspicious: reasons(data['suspicious']),
      rejected: reasons(data['rejected']),
      duplicate:
      ((data['duplicate'] as List?) ?? const []).whereType<String>().toList(),
      sessionState: (data['session_state'] ?? '').toString(),
    );
  }

  Future<AttendanceRoute> fetchRoute(
      int attendanceId, {
        bool includeSuspicious = true,
      }) async {
    try {
      final res = await _client.callKw({
        'model': _attendanceModel,
        'method': 'get_gps_route',
        'args': [
          [attendanceId]
        ],
        'kwargs': {
          'include_rejected': false,
          'include_suspicious': includeSuspicious,
        },
      });
      if (res is Map) {
        final route = _parseRoute(Map<String, dynamic>.from(res));
        ApiLogger.info(
          'fetchRoute: attendance=$attendanceId points=${route.points.length} '
              'line=${route.line.length} road=${route.road.state} '
              'roadSegs=${route.road.segments.length} gaps=${route.gaps.length}',
        );
        return route;
      }
      return const AttendanceRoute();
    } catch (e, st) {
      if (_looksForbidden(e)) throw AttendanceGpsForbidden();
      if (_looksMissing(e)) throw AttendanceGpsUnavailable();
      ApiLogger.error('fetchRoute failed', e, st);
      rethrow;
    }
  }

  /// Ask the server to compute the road route now (manual "Follow Roads").
  Future<void> computeRoadRoute(int attendanceId) async {
    await _client.callKw({
      'model': _attendanceModel,
      'method': 'action_gps_compute_road_route',
      'args': [
        [attendanceId]
      ],
      'kwargs': {},
    });
  }

  AttendanceRoute _parseRoute(Map<String, dynamic> data) {
    final points = ((data['points'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) =>
        AttendanceGpsPoint.fromRoutePayload(Map<String, dynamic>.from(e)))
        .where((p) => p.validationStatus != 'rejected')
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    var line = ((data['line'] as List?) ?? const [])
        .whereType<List>()
        .where((c) => c.length >= 2 && c[0] is num && c[1] is num)
        .map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
        .toList();
    if (line.length < 2 && points.length >= 2) {
      line = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    }

    final endpoints = ((data['fallback'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) =>
        AttendanceGpsPoint.fromRoutePayload(Map<String, dynamic>.from(e)))
        .toList();

    final gaps = ((data['gaps'] as List?) ?? const [])
        .whereType<Map>()
        .map((raw) {
      final g = Map<String, dynamic>.from(raw);
      final from = g['from'];
      final to = g['to'];
      if (from is! List || to is! List || from.length < 2 || to.length < 2) {
        return null;
      }
      return RouteGap(
        from: LatLng((from[0] as num).toDouble(), (from[1] as num).toDouble()),
        to: LatLng((to[0] as num).toDouble(), (to[1] as num).toDouble()),
        seconds: (g['seconds'] as num?)?.toDouble() ?? 0,
      );
    })
        .whereType<RouteGap>()
        .toList();

    final road = _parseRoad(data['road']);

    final summary = (data['summary'] is Map)
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : const <String, dynamic>{};

    return AttendanceRoute(
      points: points,
      line: line,
      endpoints: endpoints,
      gaps: gaps,
      road: road,
      distanceKm: (summary['total_distance_km'] as num?)?.toDouble() ?? 0,
      restricted: data['restricted'] == true,
      simplified: data['line_simplified'] == true,
      sessionId: (data['session_id'] is int) ? data['session_id'] as int : null,
    );
  }

  RoadRoute _parseRoad(dynamic raw) {
    if (raw is! Map) return const RoadRoute();
    final r = Map<String, dynamic>.from(raw);
    // segments: [[[lat,lng],[lat,lng],...], ...]
    final segments = ((r['segments'] as List?) ?? const [])
        .whereType<List>()
        .map((seg) => seg
        .whereType<List>()
        .where((c) => c.length >= 2 && c[0] is num && c[1] is num)
        .map((c) =>
        LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
        .toList())
        .where((s) => s.length >= 2)
        .toList();
    return RoadRoute(
      state: _roadState(r['state'] as String?),
      segments: segments,
      distanceKm: (r['distance_km'] as num?)?.toDouble() ?? 0,
      thinned: r['thinned'] == true,
      error: (r['error'] ?? '').toString(),
      errorCode: (r['error_code'] ?? '').toString(),
    );
  }

  bool _looksForbidden(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('accesserror') ||
        msg.contains('not allowed') ||
        msg.contains('does not allow employees');
  }

  bool _looksMissing(Object e) {
    final msg = e.toString().toLowerCase();
    final mentionsModel = msg.contains('get_gps_route') ||
        msg.contains('hr.attendance.gps') ||
        msg.contains('record_endpoint');
    final notFound = msg.contains("doesn't exist") ||
        msg.contains('does not exist') ||
        msg.contains('invalid model') ||
        msg.contains('attributeerror') ||
        msg.contains('no attribute');
    return mentionsModel && notFound && !msg.contains('invalid field');
  }
}