import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng;

import '../../core/utils/api_logger.dart';
import '../local/route_buffer_store.dart';
import '../models/attendance_gps_config.dart';
import '../models/attendance_gps_point.dart';
import '../repositories/attendance_gps_repository.dart';

@pragma('vm:entry-point')
void startAttendanceRouteCallback() {
  DartPluginRegistrant.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(_RouteTaskHandler());
}

/// Runs inside the foreground-service isolate. Samples GPS on each repeat event
/// and appends to the shared [RouteBufferStore]. It never talks to Odoo — the
/// main isolate uploads from the buffer.
///
/// Thresholds come from [AttendanceGpsConfig], i.e. from the server, so the
/// sampler never buffers a point the addon is guaranteed to throw away.
///
/// It deliberately does NOT tag anything as `check_in`. The first background
/// sample lands up to one interval after the user pressed the button and can be
/// hundreds of metres away; calling it "check-in" writes a location the
/// employee was never at when they checked in. The real check-in point is
/// uploaded by the main isolate from the position captured at button-press
/// time — see [LocationTrackingService.recordInitialPoint].
class _RouteTaskHandler extends TaskHandler {
  final RouteBufferStore _buffer = RouteBufferStore();

  static const Distance _distance = Distance();

  AttendanceGpsConfig _config = AttendanceGpsConfig.defaults;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _config = await AttendanceGpsConfig.load();
    ApiLogger.info('tracking.isolate started with $_config');
    await _sample();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _sample();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _sample() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (position.accuracy > _config.maxAccuracy) {
        ApiLogger.info(
          'tracking.sample dropped: accuracy '
              '${position.accuracy.toStringAsFixed(1)}m > ${_config.maxAccuracy}m '
              '(the server would reject it)',
        );
        return;
      }

      final existing = await _buffer.readAll();
      if (existing.isNotEmpty) {
        final last = existing.last;

        // `elapsed < min_save_interval` is a hard server rejection, and a 15 s
        // timer routinely fires at 14.97 s — hence one second of headroom.
        final elapsed =
            position.timestamp.difference(last.timestamp).inMilliseconds /
                1000.0;
        final overdue = elapsed >= _config.idleInterval;
        if (!overdue && elapsed < _config.captureInterval + 1) {
          ApiLogger.info(
            'tracking.sample skipped: ${elapsed.toStringAsFixed(1)}s since the '
                'previous point < ${_config.captureInterval + 1}s',
          );
          return;
        }

        final moved = _distance(
          LatLng(last.latitude, last.longitude),
          LatLng(position.latitude, position.longitude),
        );
        final threshold =
        math.max(_config.minMoveMeters, position.accuracy * 0.75);
        if (!overdue && moved < threshold) {
          ApiLogger.info(
            'tracking.sample skipped: moved ${moved.toStringAsFixed(1)}m < '
                '${threshold.toStringAsFixed(1)}m (stationary jitter)',
          );
          return;
        }
      }

      final sequence = await _buffer.nextSequence();
      await _buffer.append(
        AttendanceGpsPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: position.timestamp,
          sequence: sequence,
          accuracy: position.accuracy,
          altitude: position.altitude,
          speed: position.speed,
          heading: position.heading,
          eventType: AttendanceGpsPoint.movement,
        ),
      );
      ApiLogger.info(
        'tracking.sample #$sequence (${position.latitude}, '
            '${position.longitude}) ±${position.accuracy.toStringAsFixed(0)}m',
      );
      FlutterForegroundTask.updateService(
        notificationTitle: 'Attendance route tracking',
        notificationText: 'Recorded ${sequence + 1} location points.',
      );
    } catch (e) {
      ApiLogger.error('tracking.sample failed', e);
    }
  }
}

/// Main-isolate facade: starts/stops the foreground service, owns the tracking
/// session and flushes buffered points to Odoo.
class LocationTrackingService {
  LocationTrackingService._();
  static final LocationTrackingService instance = LocationTrackingService._();

  static const int _serviceId = 42501;
  static const Duration _flushInterval = Duration(seconds: 60);

  final RxBool isTracking = false.obs;
  final Rxn<int> activeAttendanceId = Rxn<int>();

  final RouteBufferStore _buffer = RouteBufferStore();
  AttendanceGpsRepository? Function()? _repoFactory;
  Timer? _flushTimer;
  int _initialisedIntervalMs = 0;
  int? _sessionId;

  AttendanceGpsConfig config = AttendanceGpsConfig.defaults;

  /// Rolling tally of why the server dropped points this shift. Surface it in
  /// a debug screen — it turns "the route looks wrong" into a specific cause.
  final RxMap<String, int> rejectionCounts = <String, int>{}.obs;

  void configure(AttendanceGpsRepository? Function() repoFactory) {
    _repoFactory = repoFactory;
  }

  Future<void> _ensureInit(Duration sampleInterval) async {
    final ms = sampleInterval.inMilliseconds;
    if (_initialisedIntervalMs == ms) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'attendance_route_tracking',
        channelName: 'Attendance Route Tracking',
        channelDescription: 'Recording your attendance route until check-out.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(ms),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialisedIntervalMs = ms;
    ApiLogger.info('tracking: foreground task initialised at ${ms}ms');
  }

  Future<bool> start({
    required int attendanceId,
    required int employeeId,
  }) async {
    ApiLogger.info(
      'tracking.start requested attendance=$attendanceId employee=$employeeId',
    );
    final repo = _repoFactory?.call();
    if (repo == null) {
      ApiLogger.error('LocationTrackingService.start without a repo factory');
    }

    rejectionCounts.clear();

    config =
    repo == null ? AttendanceGpsConfig.defaults : await repo.fetchConfig();
    await config.persist();

    if (!config.routeEnabled) {
      ApiLogger.info(
          'tracking.start aborted: route tracking disabled server-side');
      isTracking.value = false;
      return false;
    }

    // Open the session up front so uploads can use the endpoint that reports
    // *why* points are refused.
    _sessionId = await repo?.startSession(deviceInfo: 'Flutter mobile app');

    await _ensureInit(config.sampleInterval);

    if (await FlutterForegroundTask.isRunningService) {
      ApiLogger.info(
          'tracking.start: service still running — stopping it first');
      await FlutterForegroundTask.stopService();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    await _buffer.clear();
    await _buffer.setAttendanceId(attendanceId);
    activeAttendanceId.value = attendanceId;

    var result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: 'Attendance route tracking',
      notificationText: 'Recording your route until check-out.',
      callback: startAttendanceRouteCallback,
    );

    if (result is! ServiceRequestSuccess) {
      ApiLogger.error('tracking.start first attempt failed: $result — retrying');
      await FlutterForegroundTask.stopService();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: 'Attendance route tracking',
        notificationText: 'Recording your route until check-out.',
        callback: startAttendanceRouteCallback,
      );
    }

    final ok = result is ServiceRequestSuccess;
    isTracking.value = ok;
    if (ok) {
      ApiLogger.info('tracking.start OK for attendance=$attendanceId');
      _startFlushTimer();
    } else {
      ApiLogger.error('tracking.start FAILED: $result');
    }
    return ok;
  }

  /// Upload the position captured at the moment the user pressed **check-in**.
  ///
  /// This is the fix for a route whose first marker sits wherever the phone
  /// happened to be when the background service first ticked. Tagged
  /// `check_in`, so the addon treats it as an endpoint and lets it past the
  /// duplicate / no_movement / too_frequent filters.
  ///
  /// Must be called *after* [start], because start() clears the buffer.
  Future<void> recordInitialPoint(Position pos) =>
      _recordEndpoint(pos, AttendanceGpsPoint.checkIn);

  /// Upload the position captured at the moment the user pressed **check-out**.
  Future<void> recordFinalPoint(Position pos) =>
      _recordEndpoint(pos, AttendanceGpsPoint.checkOut);

  Future<void> _recordEndpoint(Position pos, String eventType) async {
    final attendanceId =
        activeAttendanceId.value ?? await _buffer.getAttendanceId();
    final repo = _repoFactory?.call();
    if (attendanceId == null || repo == null) {
      ApiLogger.info(
        'tracking.$eventType skipped (attendance=$attendanceId repo=${repo != null})',
      );
      return;
    }
    try {
      final sequence = await _buffer.peekNextSequence();
      final point = AttendanceGpsPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: pos.timestamp,
        // check-in sorts before every sample, check-out after every sample.
        sequence: eventType == AttendanceGpsPoint.checkIn ? 0 : sequence + 1,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        speed: pos.speed,
        heading: pos.heading,
        eventType: eventType,
      );
      // Use the dedicated endpoint: it writes in_/out_latitude AND files the
      // point in one call, so the two endpoints are drawn from one source.
      await repo.recordEndpoint(
        point: point,
        deviceInfo: 'Flutter mobile app',
      );
      ApiLogger.info(
        'tracking.$eventType uploaded (${pos.latitude}, ${pos.longitude}) '
            'for attendance=$attendanceId',
      );
    } catch (e, st) {
      ApiLogger.error('tracking.$eventType failed', e, st);
    }
  }

  Future<void> stop() async {
    ApiLogger.info('tracking.stop (attendance=${activeAttendanceId.value})');
    _flushTimer?.cancel();
    _flushTimer = null;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      ApiLogger.info('tracking.stop: foreground service stopped');
    }
    await flush();
    isTracking.value = false;
    activeAttendanceId.value = null;
    _sessionId = null;
    await _buffer.clear();
    await AttendanceGpsConfig.forget();
    ApiLogger.info(
      'tracking.stop complete — buffer cleared. '
          'Server rejections this shift: ${rejectionCounts.isEmpty ? "none" : rejectionCounts}',
    );
  }

  Future<void> resume({
    required int attendanceId,
    required int employeeId,
  }) async {
    activeAttendanceId.value = attendanceId;
    config = await AttendanceGpsConfig.load();
    if (await FlutterForegroundTask.isRunningService) {
      isTracking.value = true;
      _sessionId ??= await _repoFactory?.call()?.startSession(
        deviceInfo: 'Flutter mobile app',
      );
      _startFlushTimer();
      unawaited(flush());
    } else {
      await start(attendanceId: attendanceId, employeeId: employeeId);
    }
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());
  }

  Future<void> flush() async {
    final repo = _repoFactory?.call();
    final attendanceId = await _buffer.getAttendanceId();
    if (repo == null || attendanceId == null) {
      ApiLogger.info(
        'tracking.flush skipped (repo=${repo != null} attendance=$attendanceId)',
      );
      return;
    }
    try {
      final highWater = await _buffer.getHighWater();
      final points = await _buffer.readAllAfter(highWater);
      ApiLogger.info(
        'tracking.flush attendance=$attendanceId pending=${points.length} '
            'highWater=$highWater',
      );
      if (points.isEmpty) return;

      points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final batchSize = math.max(10, config.offlineBatchSize);
      var uploadedThrough = highWater;
      for (var i = 0; i < points.length; i += batchSize) {
        final batch = points.sublist(i, math.min(i + batchSize, points.length));
        await _upload(repo, attendanceId, batch);
        uploadedThrough = batch
            .map((p) => p.sequence)
            .fold<int>(uploadedThrough, (a, b) => b > a ? b : a);
        await _buffer.setHighWater(uploadedThrough);
      }
      ApiLogger.info(
        'route flush uploaded ${points.length} pts (hw=$uploadedThrough)',
      );
    } on AttendanceGpsUnavailable {
      _flushTimer?.cancel();
      _flushTimer = null;
    } catch (e, st) {
      ApiLogger.error('route flush failed (will retry)', e, st);
    }
  }

  /// Session endpoint when we have a session (gives per-point reasons),
  /// legacy RPC otherwise.
  Future<void> _upload(
      AttendanceGpsRepository repo,
      int attendanceId,
      List<AttendanceGpsPoint> batch,
      ) async {
    var sessionId = _sessionId;
    // Recover a session if it was lost (e.g. app restart mid-shift).
    sessionId ??= _sessionId = await repo.startSession(
      deviceInfo: 'Flutter mobile app',
    );
    if (sessionId == null) {
      ApiLogger.info('tracking._upload skipped: no session id available');
      return;
    }
    final result = await repo.pushPoints(sessionId, batch);
    result.rejectionHistogram.forEach((reason, count) {
      rejectionCounts[reason] = (rejectionCounts[reason] ?? 0) + count;
    });
  }
}