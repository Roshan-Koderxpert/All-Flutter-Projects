import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/attendance_gps_point.dart';

/// Cross-isolate buffer for GPS points, backed by `flutter_foreground_task`'s
/// persistent store (survives app kills; readable from both the foreground
/// service isolate and the main isolate).
///
/// Concurrency contract — avoids read/modify/write races by having a single
/// writer per key:
///   * the **service isolate** is the only writer of the points list and the
///     sequence counter ([append], [nextSequence]);
///   * the **main isolate** is the only writer of the high-water mark
///     ([setHighWater]) and the only one that [clear]s (after the service is
///     stopped).
/// The points list is append-only during a shift (bounded to a few hundred
/// small entries), so keeping the whole route buffered is cheap.
class RouteBufferStore {
  static const String _keyPoints = 'route_buffer_points';
  static const String _keyAttendance = 'route_buffer_attendance_id';
  static const String _keySeq = 'route_buffer_seq';
  static const String _keyHighWater = 'route_buffer_high_water';

  // --- attendance id -------------------------------------------------------
  Future<void> setAttendanceId(int id) =>
      FlutterForegroundTask.saveData(key: _keyAttendance, value: id);

  Future<int?> getAttendanceId() async {
    final v = await FlutterForegroundTask.getData<int>(key: _keyAttendance);
    return v;
  }

  // --- sequence (service isolate only) ------------------------------------
  Future<int> nextSequence() async {
    final current =
        await FlutterForegroundTask.getData<int>(key: _keySeq) ?? 0;
    await FlutterForegroundTask.saveData(key: _keySeq, value: current + 1);
    return current;
  }

  // add this method, alongside nextSequence()
  /// Read-only variant of nextSequence() — returns what the next sequence
  /// number would be, without incrementing. Safe to call from the main
  /// isolate (unlike nextSequence, which is documented as service-isolate-only)
  /// since it never writes.
  Future<int> peekNextSequence() async {
    return await FlutterForegroundTask.getData<int>(key: _keySeq) ?? 0;
  }

  // --- points (service isolate is the sole writer via append) -------------
  Future<void> append(AttendanceGpsPoint point) async {
    final list = await _readRaw();
    list.add(point.toJson());
    await FlutterForegroundTask.saveData(
      key: _keyPoints,
      value: jsonEncode(list),
    );
  }

  Future<List<AttendanceGpsPoint>> readAll() async {
    final list = await _readRaw();
    return list
        .map((e) => AttendanceGpsPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Points not yet uploaded (sequence strictly greater than the high-water).
  Future<List<AttendanceGpsPoint>> readAllAfter(int highWater) async {
    final all = await readAll();
    return all.where((p) => p.sequence > highWater).toList();
  }

  Future<List<Map<String, dynamic>>> _readRaw() async {
    final raw = await FlutterForegroundTask.getData<String>(key: _keyPoints);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  // --- high-water (main isolate only) -------------------------------------
  Future<int> getHighWater() async =>
      await FlutterForegroundTask.getData<int>(key: _keyHighWater) ?? -1;

  Future<void> setHighWater(int sequence) =>
      FlutterForegroundTask.saveData(key: _keyHighWater, value: sequence);

  // --- lifecycle -----------------------------------------------------------
  Future<void> clear() async {
    await FlutterForegroundTask.removeData(key: _keyPoints);
    await FlutterForegroundTask.removeData(key: _keyAttendance);
    await FlutterForegroundTask.removeData(key: _keySeq);
    await FlutterForegroundTask.removeData(key: _keyHighWater);
  }


}
