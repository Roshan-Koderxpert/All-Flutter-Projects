import 'package:odoo_rpc/odoo_rpc.dart';

/// Safe parsing of Odoo `session_info` payloads (handles Odoo's `false` sentinels).
class OdooSessionParser {
  OdooSessionParser._();

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    return fallback;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) return value;
    return fallback;
  }

  static OdooSession fromSessionInfo(
    Map<String, dynamic> info, {
    String? fallbackSessionId,
  }) {
    try {
      final session = OdooSession.fromSessionInfo(info);
      if (session.id.isEmpty && fallbackSessionId != null) {
        return session.updateSessionId(fallbackSessionId);
      }
      return session;
    } catch (_) {
      final uid = _asInt(info['uid']) ?? 0;
      if (uid <= 0) {
        throw const FormatException('Session is not authenticated');
      }

      final ctx = info['user_context'];
      final ctxMap = ctx is Map
          ? Map<String, dynamic>.from(ctx)
          : <String, dynamic>{};

      return OdooSession(
        id: _asString(info['id'], fallback: fallbackSessionId ?? ''),
        userId: uid,
        partnerId: _asInt(info['partner_id']) ?? 0,
        companyId: _asInt(info['company_id']) ?? 0,
        allowedCompanies: const [],
        userLogin: _asString(info['username'], fallback: info['login']?.toString() ?? ''),
        userName: _asString(info['name']),
        userLang: _asString(ctxMap['lang'], fallback: 'en_US'),
        userTz: _asString(ctxMap['tz'], fallback: 'UTC'),
        isSystem: _asBool(info['is_system']),
        dbName: _asString(info['db']),
        serverVersion: _asString(
          info['server_version'],
          fallback: '17',
        ),
      );
    }
  }

  static bool isAuthenticated(Map<String, dynamic> info) {
    final uid = _asInt(info['uid']);
    return uid != null && uid > 0;
  }
}
