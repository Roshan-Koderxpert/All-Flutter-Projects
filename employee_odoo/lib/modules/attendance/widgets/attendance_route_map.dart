import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_datetime.dart';
import '../../../data/models/attendance_gps_point.dart';
import '../../../data/repositories/attendance_gps_repository.dart' show RouteGap;
import 'dart:math' as math;

/// Draws the check-in → check-out route on an OpenStreetMap tile layer.
///
/// [checkIn] / [checkOut] come from the *tagged* endpoint points, not from
/// `line.first` / `line.last`. Deriving the markers from array position is what
/// made the check-in pin disappear: when the first stored sample happens to be
/// the same coordinate as the last one, `start == end` and only one pin is
/// drawn, and the polyline reads as a closed loop that was never walked.
class AttendanceRouteMap extends StatelessWidget {
  const AttendanceRouteMap({
    super.key,
    required this.points,
    this.line,
    this.gaps = const [],
    this.checkIn,
    this.checkOut,
    this.warnings = const [],
    this.distanceKmOverride,
    this.height = 260,
    this.showExpand = true,
  });

  final List<AttendanceGpsPoint> points;
  final List<LatLng>? line;
  final List<RouteGap> gaps;
  final LatLng? checkIn;
  final LatLng? checkOut;
  final List<String> warnings;

  /// Server-computed distance. Preferred over measuring the drawn line, which
  /// is simplified and possibly road-snapped.
  final double? distanceKmOverride;

  final double height;
  final bool showExpand;

  static const double _mercatorLimit = 85.05112878;

  /// Coordinates flutter_map can actually project. One NaN, one (0,0)
  /// placeholder or one out-of-range latitude makes `CameraFit` produce a
  /// non-finite zoom and every later frame throws `Infinity or NaN toInt`.
  static List<LatLng> sanitise(Iterable<LatLng> input) {
    final out = <LatLng>[];
    for (final p in input) {
      final lat = p.latitude;
      final lng = p.longitude;
      if (!lat.isFinite || !lng.isFinite) continue;
      if (lat.abs() > _mercatorLimit || lng.abs() > 180) continue;
      if (lat.abs() < 0.0001 && lng.abs() < 0.0001) continue;
      out.add(p);
    }
    return out;
  }

  static LatLng? _sanitiseOne(LatLng? p) {
    if (p == null) return null;
    final ok = sanitise([p]);
    return ok.isEmpty ? null : ok.first;
  }

  @override
  Widget build(BuildContext context) {
    final rawLatLngs =
    sanitise(points.map((p) => LatLng(p.latitude, p.longitude)));
    final start = _sanitiseOne(checkIn) ??
        (rawLatLngs.isNotEmpty ? rawLatLngs.first : null);
    final end = _sanitiseOne(checkOut) ??
        (rawLatLngs.isNotEmpty ? rawLatLngs.last : null);

    if (rawLatLngs.isEmpty && start == null) {
      return _EmptyRoute(height: height);
    }

    final sanitisedLine = line == null ? <LatLng>[] : sanitise(line!);
    final displayLine = sanitisedLine.length >= 2 ? sanitisedLine : rawLatLngs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RouteStats(
          points: points,
          distanceKmOverride: distanceKmOverride,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                _RouteMapView(
                  line: displayLine,
                  gaps: gaps,
                  start: start,
                  end: end,
                ),
                Positioned(
                  right: 6,
                  bottom: 4,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.white70,
                    child: Text(
                      '© OpenStreetMap',
                      style: AppTextStyles.style(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (showExpand)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Get.to(
                              () => _RouteFullScreen(
                            points: points,
                            line: line,
                            gaps: gaps,
                            checkIn: checkIn,
                            checkOut: checkOut,
                            warnings: warnings,
                            distanceKmOverride: distanceKmOverride,
                          ),
                          fullscreenDialog: true,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.fullscreen,
                              size: 20, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: AppTextStyles.style(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _RouteMapView extends StatelessWidget {
  const _RouteMapView({
    required this.line,
    required this.start,
    required this.end,
    this.gaps = const [],
  });

  final List<LatLng> line;
  final List<RouteGap> gaps;
  final LatLng? start;
  final LatLng? end;

  /// Degrees. Below this the bounding box is a point, and framing it asks for
  /// infinite zoom.
  static const double _minExtentDegrees = 0.000001;

  List<LatLng> get _fitTargets => [
    ...line,
    if (start != null) start!,
    if (end != null) end!,
  ];

  bool get _hasExtent {
    final pts = _fitTargets;
    if (pts.length < 2) return false;
    var minLat = pts.first.latitude;
    var maxLat = minLat;
    var minLng = pts.first.longitude;
    var maxLng = minLng;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return (maxLat - minLat) > _minExtentDegrees ||
        (maxLng - minLng) > _minExtentDegrees;
  }

  /// True when check-in and check-out sit on top of each other. Both pins are
  /// still drawn, offset, so the map never silently hides one.
  bool get _endpointsCoincide {
    if (start == null || end == null) return false;
    return const Distance()(start!, end!) < 15;
  }

  /// Evenly spaced (point, bearing) pairs along the line, for direction arrows.
  List<({LatLng at, double bearing})> _arrowAnchors(List<LatLng> line) {
    if (line.length < 2) return const [];
    const distance = Distance();

    var total = 0.0;
    for (var i = 1; i < line.length; i++) {
      total += distance(line[i - 1], line[i]);
    }
    if (total <= 0) return const [];

    // ~20 arrows max, never closer than 50 m so they don't clump on a zigzag.
    final step = math.max(50.0, total / 20);

    final out = <({LatLng at, double bearing})>[];
    var carried = step / 2; // offset so the first arrow isn't on the start pin
    for (var i = 1; i < line.length; i++) {
      final a = line[i - 1];
      final b = line[i];
      final segment = distance(a, b);
      if (segment <= 0) continue;
      final bearing = distance.bearing(a, b);
      var travelled = carried;
      while (travelled <= segment) {
        final t = travelled / segment;
        out.add((
        at: LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ),
        bearing: bearing,
        ));
        travelled += step;
      }
      carried = travelled - segment;
    }
    return out;
  }

  List<Marker> _arrowMarkers(List<LatLng> line) => [
    for (final a in _arrowAnchors(line))
      Marker(
        point: a.at,
        width: 18,
        height: 18,
        rotate: false, // bearing is absolute, must not counter-rotate
        child: Transform.rotate(
          angle: a.bearing * math.pi / 180,
          child: Icon(
            Icons.navigation, // points north at 0 rad
            size: 15,
            color: Colors.white,
            shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
          ),
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final center = start ?? (line.isNotEmpty ? line.first : const LatLng(0, 0));

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        minZoom: 2,
        maxZoom: 18,
        initialCameraFit: _hasExtent
            ? CameraFit.coordinates(
          coordinates: _fitTargets,
          padding: const EdgeInsets.all(40),
          maxZoom: 17,
        )
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kodoo.hrms',
          maxNativeZoom: 19,
        ),
        if (gaps.isNotEmpty)
          PolylineLayer(
            polylines: [
              for (final gap in gaps)
                Polyline(
                  points: [gap.from, gap.to],
                  strokeWidth: 3,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
            ],
          ),
        if (line.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: line,
                strokeWidth: 4,
                color: AppColors.primary,
                borderStrokeWidth: 1,
                borderColor: Colors.white,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            ..._arrowMarkers(line),

            for (final p in line.skip(1).take(
              line.length > 2 ? line.length - 2 : 0,
            ))
              Marker(
                point: p,
                width: 8,
                height: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            if (start != null)
              _pin(start!, Colors.green, Icons.play_circle_fill),
            if (end != null)
              _pin(
                end!,
                Colors.red,
                Icons.stop_circle,
                // Nudge the check-out pin up when it lands on the check-in pin,
                // so "started and finished in the same place" is visible rather
                // than looking like a missing marker.
                alignment: _endpointsCoincide
                    ? const Alignment(0.6, -1.6)
                    : Alignment.topCenter,
              ),
          ],
        ),
      ],
    );
  }

  Marker _pin(
      LatLng point,
      Color color,
      IconData icon, {
        Alignment alignment = Alignment.topCenter,
      }) =>
      Marker(
        point: point,
        width: 34,
        height: 34,
        alignment: alignment,
        child: Icon(icon, color: color, size: 26),
      );
}

class _RouteStats extends StatelessWidget {
  const _RouteStats({required this.points, this.distanceKmOverride});

  final List<AttendanceGpsPoint> points;
  final double? distanceKmOverride;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat(Icons.route, '${_distanceKm().toStringAsFixed(2)} km', 'Distance'),
        const SizedBox(width: 20),
        _stat(Icons.timer_outlined, _durationLabel(), 'Duration'),
        const SizedBox(width: 20),
        _stat(Icons.place_outlined, '${points.length}', 'Points'),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.style(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _distanceKm() {
    final override = distanceKmOverride;
    if (override != null && override > 0) return override;
    if (points.length < 2) return 0;
    const distance = Distance();
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = LatLng(points[i - 1].latitude, points[i - 1].longitude);
      final b = LatLng(points[i].latitude, points[i].longitude);
      if (!a.latitude.isFinite ||
          !a.longitude.isFinite ||
          !b.latitude.isFinite ||
          !b.longitude.isFinite) {
        continue;
      }
      meters += distance(a, b);
    }
    return meters.isFinite ? meters / 1000.0 : 0;
  }

  String _durationLabel() {
    if (points.length < 2) return '—';
    final diff = points.last.timestamp.difference(points.first.timestamp);
    if (diff.isNegative) return '—';
    return OdooDateTime.formatDurationHhMm(diff.inMinutes / 60.0);
  }
}

class _EmptyRoute extends StatelessWidget {
  const _EmptyRoute({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height * 0.5,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined,
              size: 32, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'No route recorded. Points are captured periodically while you '
                  'are checked in and moving.',
              textAlign: TextAlign.center,
              style: AppTextStyles.style(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteFullScreen extends StatelessWidget {
  const _RouteFullScreen({
    required this.points,
    this.line,
    this.gaps = const [],
    this.checkIn,
    this.checkOut,
    this.warnings = const [],
    this.distanceKmOverride,
  });

  final List<AttendanceGpsPoint> points;
  final List<LatLng>? line;
  final List<RouteGap> gaps;
  final LatLng? checkIn;
  final LatLng? checkOut;
  final List<String> warnings;
  final double? distanceKmOverride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Route'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: AttendanceRouteMap(
          points: points,
          line: line,
          gaps: gaps,
          checkIn: checkIn,
          checkOut: checkOut,
          warnings: warnings,
          distanceKmOverride: distanceKmOverride,
          height: MediaQuery.of(context).size.height - 260,
          showExpand: false,
        ),
      ),
    );
  }
}