import 'package:flutter/foundation.dart';

/// Collects step-by-step diagnostics for the Odoo TOTP HTTP flow.
class TotpDebugLog {
  TotpDebugLog();

  final List<String> _lines = [];

  List<String> get lines => List.unmodifiable(_lines);

  String get summary =>
      _lines.isEmpty ? 'No debug output.' : _lines.join('\n');

  void step(String name, String detail) {
    final line = '[$name] $detail';
    _lines.add(line);
    debugPrint('TOTP_DEBUG $line');
  }

  void error(String name, Object error, [StackTrace? stack]) {
    step(name, 'ERROR: $error');
    if (stack != null && kDebugMode) {
      step(name, 'STACK: $stack');
    }
  }
}
