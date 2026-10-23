import 'dart:async';

import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/api_logger.dart';
import '../../../data/models/attendance_gps_point.dart';
import '../../../data/models/attendance_record.dart';
import '../../../data/repositories/attendance_gps_repository.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../auth/controllers/auth_controller.dart';

class AttendanceDetailController extends GetxController {
  AttendanceDetailController({required this.recordId});

  final int recordId;

  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final record = Rxn<AttendanceRecord>();

  final routePoints = <AttendanceGpsPoint>[].obs;
  final isLoadingRoute = false.obs;

  final routeUnavailable = false.obs;
  final routeForbidden = false.obs;
  final routeErrorMessage = ''.obs;

  /// The polyline actually drawn: the server's road segments joined when road
  /// snapping is ready, otherwise the raw recorded line. The app does NO
  /// snapping of its own any more — the addon owns that.
  final routeLine = <LatLng>[].obs;

  /// Separate road segments, so a multi-segment road route (with real gaps
  /// between segments) is drawn as separate lines rather than one bridged line.
  final roadSegments = <List<LatLng>>[].obs;

  final routeGaps = <RouteGap>[].obs;
  final routeEndpoints = <AttendanceGpsPoint>[].obs;
  final routeDistanceKm = 0.0.obs;
  final routeSimplified = false.obs;

  final checkInLocation = Rxn<LatLng>();
  final checkOutLocation = Rxn<LatLng>();

  /// `queued` while the server cron is still computing the road route.
  final roadState = Rxn<RoadRouteState>();
  final routeWarnings = <String>[].obs;

  Timer? _roadPollTimer;
  int _roadPolls = 0;
  static const int _maxRoadPolls = 6;

  AttendanceRepository? get _repo {
    final client = Get.find<AuthController>().odooClient;
    if (client == null) return null;
    return AttendanceRepository(client);
  }

  bool get hasRoute => routeLine.length >= 2 || routePoints.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    loadDetail();
  }

  @override
  void onClose() {
    _roadPollTimer?.cancel();
    super.onClose();
  }

  Future<void> loadDetail() async {
    final repo = _repo;
    if (repo == null) {
      errorMessage.value = 'Not connected to server';
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await repo.fetchRecordById(recordId);
      if (result == null) {
        errorMessage.value = 'Attendance record not found';
        record.value = null;
      } else {
        record.value = result;
        loadRoute();
      }
    } catch (_) {
      errorMessage.value = 'Failed to load attendance details';
      record.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadRoute() async {
    final client = Get.find<AuthController>().odooClient;
    if (client == null) return;

    isLoadingRoute.value = true;
    routeUnavailable.value = false;
    routeForbidden.value = false;
    routeErrorMessage.value = '';
    try {
      final route = await AttendanceGpsRepository(client).fetchRoute(recordId);

      routePoints.assignAll(route.points);
      routeGaps.assignAll(route.gaps);
      routeEndpoints.assignAll(route.endpoints);
      routeDistanceKm.value =
      route.road.isReady && route.road.distanceKm > 0
          ? route.road.distanceKm
          : route.distanceKm;
      routeSimplified.value = route.simplified;
      checkInLocation.value = route.checkInLocation;
      checkOutLocation.value = route.checkOutLocation;
      roadState.value = route.road.state;

      _applyGeometry(route);
      routeWarnings.assignAll(_buildWarnings(route));

      // If the server is still computing the road route, poll a few times so
      // the straight line quietly upgrades to the snapped one without a manual
      // refresh.
      if (route.road.isPending) {
        // Force a synchronous server-side compute (no time budget) instead of
        // waiting up to 10 min for the cron, then poll as a fallback.
        unawaited(_forceRoadRouteThenReload());
      } else {
        _roadPollTimer?.cancel();
      }


      ApiLogger.info(
        'loadRoute: attendance=$recordId drawn=${routeLine.length} '
            'roadSegments=${roadSegments.length} road=${route.road.state}',
      );
    } on AttendanceGpsUnavailable {
      routeUnavailable.value = true;
      _clearRoute();
    } on AttendanceGpsForbidden catch (e) {
      routeForbidden.value = true;
      routeErrorMessage.value = e.message;
      _clearRoute();
    } catch (e, st) {
      ApiLogger.error('loadRoute failed', e, st);
      routeErrorMessage.value = 'Could not load the route.';
      _clearRoute();
    } finally {
      isLoadingRoute.value = false;
    }
  }

  void _applyGeometry(AttendanceRoute route) {
    if (route.road.isReady && route.road.hasGeometry) {
      // Draw the server's snapped roads. Each segment stays separate.
      roadSegments.assignAll(route.road.segments);
      final flat = <LatLng>[];
      for (final seg in route.road.segments) {
        flat.addAll(seg);
      }
      routeLine.assignAll(flat);
    } else {
      // No road route (disabled, queued, skipped or failed): draw the raw
      // recorded line as-is.
      roadSegments.clear();
      final line = route.line.isNotEmpty
          ? route.line
          : route.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
      routeLine.assignAll(_dropConsecutiveDuplicates(line));
    }
  }

  void _startRoadPolling() {
    _roadPollTimer?.cancel();
    _roadPolls = 0;
    _roadPollTimer = Timer.periodic(const Duration(seconds: 8), (t) async {
      _roadPolls++;
      if (_roadPolls > _maxRoadPolls) {
        t.cancel();
        return;
      }
      final client = Get.find<AuthController>().odooClient;
      if (client == null) {
        t.cancel();
        return;
      }
      try {
        final route = await AttendanceGpsRepository(client).fetchRoute(recordId);
        roadState.value = route.road.state;
        if (!route.road.isPending) {
          t.cancel();
          routeDistanceKm.value =
          route.road.isReady && route.road.distanceKm > 0
              ? route.road.distanceKm
              : route.distanceKm;
          _applyGeometry(route);
          routeWarnings.assignAll(_buildWarnings(route));
          ApiLogger.info('road route ready after $_roadPolls poll(s): '
              '${route.road.state}');
        }
      } catch (_) {
        t.cancel();
      }
    });
  }

  /// Manual "Follow Roads": ask the server to compute now, then reload.
  Future<void> requestRoadRoute() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await AttendanceGpsRepository(Get.find<AuthController>().odooClient!)
          .computeRoadRoute(recordId);
      await loadRoute();
    } catch (e, st) {
      ApiLogger.error('requestRoadRoute failed', e, st);
      routeErrorMessage.value = 'Could not compute the road route.';
    }
  }

  Future<void> _forceRoadRouteThenReload() async {
    final client = Get.find<AuthController>().odooClient;
    if (client == null) return;
    try {
      await AttendanceGpsRepository(client).computeRoadRoute(recordId);
      final route = await AttendanceGpsRepository(client).fetchRoute(recordId);
      roadState.value = route.road.state;
      routeDistanceKm.value = route.road.isReady && route.road.distanceKm > 0
          ? route.road.distanceKm
          : route.distanceKm;
      _applyGeometry(route);
      routeWarnings.assignAll(_buildWarnings(route));
      ApiLogger.info('forced road route: ${route.road.state} '
          'segs=${roadSegments.length}');
      // If OSRM was slow and it's still queued, fall back to polling.
      if (route.road.isPending) _startRoadPolling();
    } catch (e) {
      ApiLogger.info('force compute failed, falling back to polling: $e');
      _startRoadPolling();
    }
  }

  List<String> _buildWarnings(AttendanceRoute route) {
    final warnings = <String>[];
    final road = route.road;

    if (road.isPending) {
      warnings.add('The road-matched route is still being computed. Showing '
          'the recorded track for now.');
    } else if (road.state == RoadRouteState.failed && road.error.isNotEmpty) {
      warnings.add('Road matching could not be completed: ${road.error} '
          'Showing the recorded track.');
    } else if (road.state == RoadRouteState.skipped) {
      warnings.add('The route is too short to match to roads.');
    } else if (road.state == RoadRouteState.partial) {
      warnings.add('Part of the journey could not be matched to roads and is '
          'shown as recorded.');
    }
    if (road.thinned) {
      warnings.add('The route was simplified to keep the map responsive.');
    }

    final hasTaggedCheckIn =
        route.points.any((p) => p.eventType == AttendanceGpsPoint.checkIn) ||
            route.endpoints.any((p) => p.eventType == AttendanceGpsPoint.checkIn);
    if (!hasTaggedCheckIn && route.points.isNotEmpty) {
      warnings.add('No check-in position was recorded; the route starts at the '
          'first tracked point.');
    }
    if (route.endpointsCollapsed && route.points.length > 1) {
      warnings.add('Check-in and check-out are at the same place, so the path '
          'forms a loop.');
    }
    if (route.gaps.isNotEmpty) {
      warnings.add('${route.gaps.length} tracking gap'
          '${route.gaps.length == 1 ? '' : 's'} — faded segments were not '
          'recorded.');
    }
    return warnings;
  }

  List<LatLng> _dropConsecutiveDuplicates(List<LatLng> line) {
    if (line.length < 2) return line;
    const distance = Distance();
    final out = <LatLng>[line.first];
    for (final p in line.skip(1)) {
      if (distance(out.last, p) >= 1) out.add(p);
    }
    return out.length >= 2 ? out : line;
  }

  void _clearRoute() {
    routePoints.clear();
    routeLine.clear();
    roadSegments.clear();
    routeGaps.clear();
    routeEndpoints.clear();
    routeWarnings.clear();
    checkInLocation.value = null;
    checkOutLocation.value = null;
    roadState.value = null;
    routeDistanceKm.value = 0;
    routeSimplified.value = false;
    _roadPollTimer?.cancel();
  }
}