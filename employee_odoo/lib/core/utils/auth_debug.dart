import 'package:flutter/foundation.dart';

import '../../data/models/account_model.dart';

/// Debug logging for multi-account auth flows. Filter console with: AuthAccount
class AuthDebug {
  AuthDebug._();

  static const _tag = 'AuthAccount';

  static void log(String event, [Map<String, Object?>? data]) {
    if (!kDebugMode) return;
    if (data == null || data.isEmpty) {
      debugPrint('[$_tag] $event');
      return;
    }
    final buffer = StringBuffer('[$_tag] $event');
    for (final entry in data.entries) {
      buffer.write(' | ${entry.key}=${entry.value}');
    }
    debugPrint(buffer.toString());
  }

  static void accounts(String event, List<AccountModel> accounts) {
    if (!kDebugMode) return;
    if (accounts.isEmpty) {
      log('$event (no saved accounts)');
      return;
    }
    for (final account in accounts) {
      log(
        event,
        {
          'id': account.id,
          'user': account.username,
          'db': account.database,
          'active': account.isActive,
          'hasSession': account.hasStoredSession,
          'hasPassword': account.password.isNotEmpty,
          'lastLogin': account.lastLogin?.toIso8601String(),
        },
      );
    }
  }
}
