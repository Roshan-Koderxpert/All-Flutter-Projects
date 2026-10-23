import 'package:flutter/foundation.dart';

/// Debug-only API logging. Filter console with tag: AttendanceAPI
class ApiLogger {
  ApiLogger._();

  static const String _tag = 'AttendanceAPI';

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[$_tag] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[$_tag] ERROR: $message');
      if (error != null) debugPrint('[$_tag]   exception: $error');
      if (stack != null) debugPrint('[$_tag]   stack: $stack');
    }
  }

  static void json(String label, dynamic data) {
    if (kDebugMode) {
      debugPrint('[$_tag] $label => $data');
    }
  }
}
