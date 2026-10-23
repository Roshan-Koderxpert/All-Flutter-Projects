import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

/// Thrown when the "Restrict Mobile App Access" setting blocks a user from
/// signing in to the mobile app. The message is shown to the user as-is.
class MobileAccessDeniedException implements Exception {
  const MobileAccessDeniedException([this.message =
      "You're not allowed to use the mobile app. Please contact HR."]);

  final String message;

  @override
  String toString() => message;
}

/// Reads the HRMS "Restrict Mobile App Access" setting from `res.company`
/// (added by the hr_attendance_gps module) to decide whether a **user** login
/// may proceed on the mobile app.
///
/// The backend rule (`res.company._hr_mobile_app_allows`) is: if
/// `hr_mobile_app_restricted` is off, everyone is allowed; if it is on, only
/// `hr_mobile_app_user_id` is allowed. That method is private and not callable
/// over RPC, so we read the two plain fields and apply the same rule here.
class MobileAccessRepository {
  MobileAccessRepository(this._client);

  final OdooClient _client;

  /// Whether the user with [userId] may use the mobile app.
  ///
  /// Fails **open** (returns `true`) whenever the setting can't be evaluated —
  /// e.g. the module isn't installed and the fields don't exist — so servers
  /// without the feature keep working exactly as before.
  Future<bool> canUseMobileApp({required int userId}) async {
    try {
      final companyId = await _resolveUserCompanyId(userId);
      if (companyId == null) return true;

      final result = await _client.callKw({
        'model': 'res.company',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', companyId],
          ],
          ['hr_mobile_app_restricted', 'hr_mobile_app_user_id'],
        ],
        'kwargs': {'limit': 1},
      });

      if (result is! List || result.isEmpty) return true;
      final row = Map<String, dynamic>.from(result.first as Map);

      final restricted = row['hr_mobile_app_restricted'] == true;
      if (!restricted) return true;

      final allowed = row['hr_mobile_app_user_id'];
      if (allowed is List && allowed.isNotEmpty) {
        return allowed.first == userId;
      }
      // Restricted but nobody selected → matches the backend intent: block.
      return false;
    } catch (e) {
      // Field/module missing or transient error → don't lock anyone out.
      debugPrint('MobileAccessRepository: check failed, allowing: $e');
      return true;
    }
  }

  Future<int?> _resolveUserCompanyId(int userId) async {
    final users = await _client.callKw({
      'model': 'res.users',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', userId],
        ],
        ['company_id'],
      ],
      'kwargs': {'limit': 1},
    });
    if (users is! List || users.isEmpty) return null;
    final company = Map<String, dynamic>.from(users.first as Map)['company_id'];
    if (company is List && company.isNotEmpty && company.first is int) {
      return company.first as int;
    }
    return null;
  }
}
