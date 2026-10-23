import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:odoo_rpc/odoo_rpc.dart';

import 'odoo_http_session.dart';
import 'odoo_session_parser.dart';

/// Result of an Odoo login attempt — either fully authenticated or 2FA required.
class LoginAttemptResult {
  const LoginAttemptResult._({
    required this.requiresTotp,
    this.session,
    this.partialSessionId,
  });

  final bool requiresTotp;
  final OdooSession? session;
  final String? partialSessionId;

  factory LoginAttemptResult.authenticated(OdooSession session) {
    return LoginAttemptResult._(
      requiresTotp: false,
      session: session,
    );
  }

  factory LoginAttemptResult.totpRequired(String partialSessionId) {
    return LoginAttemptResult._(
      requiresTotp: true,
      partialSessionId: partialSessionId,
    );
  }
}

class OdooAuthService {
  OdooAuthService._();

  static String _jsonRpcId() =>
      sha1.convert(utf8.encode(DateTime.now().toString())).toString();

  /// Authenticate via JSON-RPC and detect when Odoo requires TOTP.
  ///
  /// Odoo 17+ returns `{uid: null}` with a partial `session_id` cookie when
  /// MFA is enabled — see web/controllers/session.py.
  static Future<LoginAttemptResult> attemptAuthenticate({
    required String baseUrl,
    required String db,
    required String login,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/web/session/authenticate');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {'db': db, 'login': login, 'password': password},
      'id': _jsonRpcId(),
    });

    final response = await http
        .post(
          uri,
          body: body,
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw OdooException(decoded['error'].toString());
    }

    final httpSession = OdooHttpSession();
    httpSession.absorbCookies(response.headers);

    final sessionInfo = Map<String, dynamic>.from(
      decoded['result'] as Map<dynamic, dynamic>? ?? {},
    );

    final cookieSessionId = httpSession.sessionId;
    final bodySessionId = sessionInfo['id'] as String?;
    final effectiveSessionId = cookieSessionId ?? bodySessionId ?? '';

    final uid = sessionInfo['uid'];
    if (uid is int && uid > 0) {
      final session = OdooSessionParser.fromSessionInfo(
        sessionInfo,
        fallbackSessionId: effectiveSessionId,
      );
      final sessionId =
          effectiveSessionId.isNotEmpty ? effectiveSessionId : session.id;
      return LoginAttemptResult.authenticated(
        sessionId.isEmpty ? session : session.updateSessionId(sessionId),
      );
    }

    // Odoo 17+ MFA: `{uid: null}` — partial session cookie holds `pre_uid`.
    final requiresTotp = uid == null ||
        uid == false ||
        (uid is int && uid <= 0);

    if (requiresTotp && effectiveSessionId.isNotEmpty) {
      debugPrint(
        'AUTH_2FA: uid=$uid session=${effectiveSessionId.substring(0, effectiveSessionId.length.clamp(0, 12))}... '
        '(web login bootstrap will run on TOTP screen)',
      );
      return LoginAttemptResult.totpRequired(effectiveSessionId);
    }

    if (requiresTotp) {
      debugPrint(
        'AUTH_2FA: uid=$uid but NO session cookie — TOTP will use web login bootstrap',
      );
      return LoginAttemptResult.totpRequired('');
    }

    if (uid is bool && uid == false) {
      throw OdooException('Authentication failed');
    }

    throw OdooException('Authentication failed');
  }
}
