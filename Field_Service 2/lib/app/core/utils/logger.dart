import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void info(String message, {String? tag}) {
    // if (kDebugMode) {
    //   debugPrint('ℹ️  [${tag ?? 'FSM'}] $message');
    // }
  }

  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('✅ [${tag ?? 'FSM'}] $message');
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('⚠️  [${tag ?? 'FSM'}] $message');
    }
  }

  static void error(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      debugPrint('❌ [${tag ?? 'FSM'}] $message');
      if (error != null) debugPrint('   Error: $error');
    }
  }

  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('🔍 [${tag ?? 'FSM'}] $message');
    }
  }
}