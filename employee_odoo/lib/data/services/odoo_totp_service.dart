import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'odoo_http_session.dart';
import 'odoo_session_parser.dart';
import 'totp_debug_log.dart';

/// Odoo TOTP (2FA) verification via the web login flow (required for Odoo 15+).
class OdooTotpService {
  OdooTotpService._();

  static String _jsonRpcId() =>
      sha1.convert(utf8.encode(DateTime.now().toString())).toString();

  static Map<String, String> _defaultHeaders(String referer) => {
        'User-Agent': 'EmployeeOdooApp/1.0',
        'Referer': referer,
      };

  static String _encodeForm(Map<String, String> fields) {
    return fields.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
  }

  /// Fetch session info for a fully authenticated session cookie.
  static Future<Map<String, dynamic>> getSessionInfo(
    String baseUrl,
    String sessionId, {
    TotpDebugLog? log,
  }) async {
    final uri = Uri.parse('$baseUrl/web/session/get_session_info');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {},
      'id': _jsonRpcId(),
    });

    final response = await http
        .post(
          uri,
          body: body,
          headers: {
            'Content-Type': 'application/json',
            'Cookie': 'session_id=$sessionId',
            ..._defaultHeaders('$baseUrl/web'),
          },
        )
        .timeout(const Duration(seconds: 15));

    log?.step(
      'get_session_info',
      'status=${response.statusCode} body=${_clip(response.body, 300)}',
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw Exception(decoded['error'].toString());
    }

    return Map<String, dynamic>.from(decoded['result'] as Map);
  }

  /// Verify TOTP using the browser-style login flow.
  ///
  /// JSON-RPC `/web/session/authenticate` only returns `{uid: null}` for MFA and
  /// does **not** prepare `pre_uid` for `/web/login/totp`. We must POST
  /// `/web/login` first (see odooly + Odoo session controller comments).
  static Future<TotpVerifyResult> verifyTotpCode({
    required String baseUrl,
    required String sessionId,
    required String code,
    required String db,
    required String login,
    required String password,
    TotpDebugLog? log,
  }) async {
    final debug = log ?? TotpDebugLog();

    try {
      debug.step('start', 'baseUrl=$baseUrl db=$db login=$login');
      debug.step(
        'initial_session',
        sessionId.isEmpty
            ? 'EMPTY (will bootstrap via web login)'
            : '${sessionId.substring(0, sessionId.length.clamp(0, 12))}...',
      );

      final httpSession = await _bootstrapWebTotpSession(
        baseUrl: baseUrl,
        db: db,
        login: login,
        password: password,
        initialSessionId: sessionId,
        log: debug,
      );

      if (httpSession == null || httpSession.sessionId == null) {
        return TotpVerifyResult(
          success: false,
          message:
              'Could not start 2FA session. Sign in again from the login screen.',
          debugLog: debug,
          errorCode: 'bootstrap_failed',
        );
      }

      final totpPageUrl = '$baseUrl/web/login/totp';
      final totpPage = await httpSession.get(
        Uri.parse(totpPageUrl),
        headers: _defaultHeaders('$baseUrl/web/login'),
      );

      debug.step(
        'get_totp_page',
        'status=${totpPage.statusCode} session=${_sessionPreview(httpSession.sessionId)} '
        'hasTotpForm=${_hasTotpForm(totpPage.body)}',
      );

      var csrfToken = _extractCsrfToken(totpPage.body);
      if (csrfToken.isEmpty) {
        csrfToken = await _fetchCsrfToken(httpSession, baseUrl, debug);
      }

      debug.step(
        'csrf',
        csrfToken.isEmpty
            ? 'MISSING — page snippet: ${_clip(totpPage.body, 200)}'
            : 'ok prefix=${csrfToken.substring(0, csrfToken.length.clamp(0, 16))}...',
      );

      if (csrfToken.isEmpty) {
        return TotpVerifyResult(
          success: false,
          message:
              'Security token (CSRF) not found. The server may not have reached the TOTP step.',
          debugLog: debug,
          errorCode: 'csrf_missing',
        );
      }

      final formBody = _encodeForm({
        'totp_token': code,
        'csrf_token': csrfToken,
      });

      final totpResponse = await httpSession.send(
        http.Request('POST', Uri.parse(totpPageUrl))
          ..headers.addAll(_defaultHeaders(totpPageUrl))
          ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
          ..followRedirects = false
          ..body = formBody,
      );

      final activeSessionId = httpSession.sessionId!;

      debug.step(
        'post_totp',
        'status=${totpResponse.statusCode} '
        'location=${totpResponse.headers['location'] ?? '-'} '
        'session=${_sessionPreview(activeSessionId)} '
        'body=${_clip(totpResponse.body, 250)}',
      );

      final sessionInfo = await _probeAuthenticatedSession(
        baseUrl,
        activeSessionId,
        debug,
      );
      if (sessionInfo != null) {
        debug.step('success', 'uid=${sessionInfo['uid']}');
        return TotpVerifyResult(
          success: true,
          sessionId: activeSessionId,
          sessionInfo: sessionInfo,
          debugLog: debug,
        );
      }

      final status = totpResponse.statusCode;
      if (_isRedirect(status)) {
        final location = totpResponse.headers['location'] ?? '';
        if (!location.contains('totp')) {
          debug.step('redirect_success', 'location=$location');
          return TotpVerifyResult(
            success: true,
            sessionId: activeSessionId,
            debugLog: debug,
          );
        }
      }

      if (status == 200) {
        final rawError = _parseHtmlError(totpResponse.body);
        final isCsrf = rawError.toLowerCase().contains('csrf') ||
            totpResponse.body.toLowerCase().contains('csrf');
        return TotpVerifyResult(
          success: false,
          message: rawError,
          debugLog: debug,
          errorCode: isCsrf ? 'csrf_rejected' : 'invalid_code',
        );
      }

      if (status == 400) {
        return TotpVerifyResult(
          success: false,
          message:
              'Server rejected the request (400). Usually a CSRF or session mismatch.',
          debugLog: debug,
          errorCode: 'http_400',
        );
      }

      return TotpVerifyResult(
        success: false,
        message: 'Unexpected response ($status).',
        debugLog: debug,
        errorCode: 'http_$status',
      );
    } catch (e, st) {
      debug.error('exception', e, st);
      return TotpVerifyResult(
        success: false,
        message: 'Verification error: $e',
        debugLog: debug,
        errorCode: 'exception',
      );
    }
  }

  /// POST `/web/login` to create the partial session (`pre_uid`) Odoo needs
  /// before `/web/login/totp` will accept a code.
  static Future<OdooHttpSession?> _bootstrapWebTotpSession({
    required String baseUrl,
    required String db,
    required String login,
    required String password,
    required String initialSessionId,
    required TotpDebugLog log,
  }) async {
    final session = OdooHttpSession(initialSessionId);

    final loginPageUri = Uri.parse('$baseUrl/web/login').replace(
      queryParameters: {'db': db},
    );

    final loginPage = await session.get(
      loginPageUri,
      headers: _defaultHeaders('$baseUrl/web'),
    );

    log.step(
      'bootstrap_get_login',
      'status=${loginPage.statusCode} session=${_sessionPreview(session.sessionId)}',
    );

    var csrf = _extractCsrfToken(loginPage.body);
    if (csrf.isEmpty) {
      log.step('bootstrap_csrf', 'missing on login page');
      return null;
    }

    final loginPostUri = Uri.parse('$baseUrl/web/login');
    final loginResponse = await session.send(
      http.Request('POST', loginPostUri)
        ..headers.addAll(_defaultHeaders(loginPageUri.toString()))
        ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
        ..followRedirects = false
        ..body = _encodeForm({
          'csrf_token': csrf,
          'login': login,
          'password': password,
          'db': db,
          'redirect': '',
        }),
    );

    log.step(
      'bootstrap_post_login',
      'status=${loginResponse.statusCode} '
      'location=${loginResponse.headers['location'] ?? '-'} '
      'session=${_sessionPreview(session.sessionId)} '
      'hasTotpForm=${_hasTotpForm(loginResponse.body)}',
    );

    if (_isRedirect(loginResponse.statusCode)) {
      final location = loginResponse.headers['location'] ?? '';
      final totpUri = location.startsWith('http')
          ? Uri.parse(location)
          : Uri.parse('$baseUrl$location');

      if (location.contains('totp')) {
        final totpPage = await session.get(
          totpUri,
          headers: _defaultHeaders(loginPostUri.toString()),
        );
        log.step(
          'bootstrap_follow_totp_redirect',
          'status=${totpPage.statusCode} hasTotpForm=${_hasTotpForm(totpPage.body)}',
        );
      }
    }

    if (_hasTotpForm(loginResponse.body)) {
      return session;
    }

    // Already on TOTP step after redirect + GET above.
    final probe = await session.get(
      Uri.parse('$baseUrl/web/login/totp'),
      headers: _defaultHeaders('$baseUrl/web/login'),
    );
    log.step(
      'bootstrap_probe_totp',
      'status=${probe.statusCode} hasTotpForm=${_hasTotpForm(probe.body)}',
    );

    if (_hasTotpForm(probe.body)) {
      return session;
    }

    log.step(
      'bootstrap_failed',
      'Server did not return TOTP form. Snippet: ${_clip(probe.body, 300)}',
    );
    return null;
  }

  static Future<Map<String, dynamic>?> _probeAuthenticatedSession(
    String baseUrl,
    String sessionId,
    TotpDebugLog log,
  ) async {
    try {
      final info = await getSessionInfo(baseUrl, sessionId, log: log);
      if (OdooSessionParser.isAuthenticated(info)) {
        return info;
      }
      log.step('probe', 'uid not set: ${info['uid']}');
    } catch (e) {
      log.step('probe', 'failed: $e');
    }
    return null;
  }

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  static bool _hasTotpForm(String html) {
    final lower = html.toLowerCase();
    return lower.contains('totp_token') ||
        lower.contains('auth_totp') ||
        lower.contains('two-factor authentication') ||
        lower.contains('authentication code');
  }

  static String _sessionPreview(String? id) {
    if (id == null || id.isEmpty) return 'none';
    return '${id.substring(0, id.length.clamp(0, 10))}...';
  }

  static String _clip(String text, int max) {
    final trimmed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}...';
  }

  static String _extractCsrfToken(String html) {
    final patterns = [
      RegExp(r'''csrf_token['"]?\s*:\s*['"]([^'"]+)['"]'''),
      RegExp(
        r'name="csrf_token"[^>]*value="([^"]+)"|value="([^"]+)"[^>]*name="csrf_token"',
      ),
      RegExp(
        "name='csrf_token'[^>]*value='([^']+)'|value='([^']+)'[^>]*name='csrf_token'",
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;
      final token = match.group(1) ?? match.group(2);
      if (token != null && token.isNotEmpty) return token;
    }
    return '';
  }

  static Future<String> _fetchCsrfToken(
    OdooHttpSession session,
    String baseUrl,
    TotpDebugLog log,
  ) async {
    try {
      final response = await session.get(
        Uri.parse('$baseUrl/web/csrf-token'),
        headers: _defaultHeaders('$baseUrl/web'),
      );

      log.step(
        'csrf_endpoint',
        'status=${response.statusCode} body=${_clip(response.body, 120)}',
      );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.startsWith('{')) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          return (data['token'] ?? data['csrf_token'] ?? '').toString();
        }
        if (body.isNotEmpty && !body.contains('<')) {
          return body;
        }
      }
    } catch (e) {
      log.step('csrf_endpoint', 'error: $e');
    }
    return '';
  }

  static String _parseHtmlError(String html) {
    final lower = html.toLowerCase();

    if (lower.contains('csrf validation failed') ||
        lower.contains('no csrf validation token')) {
      return 'CSRF token rejected by server. Please go back and sign in again.';
    }

    final patterns = [
      RegExp(r'alert-danger[^>]*>\s*([^<]{5,200})', dotAll: true),
      RegExp(r'class="[^"]*alert[^"]*"[^>]*>\s*([^<]{5,200})', dotAll: true),
      RegExp(r'Invalid authentication code', caseSensitive: false),
      RegExp(r'Access Denied', caseSensitive: false),
      RegExp(r'Too many', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;
      final raw = (match.groupCount > 0 ? match.group(1) : match.group(0))
              ?.trim() ??
          '';
      if (raw.isNotEmpty) return _friendlyError(raw);
    }

    return 'Incorrect code. Please check your authenticator app and try again.';
  }

  static String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('too many') || lower.contains('throttl')) {
      return 'Too many attempts. Please wait before trying again.';
    }
    if (lower.contains('expired')) {
      return 'Code expired. Enter the current code from your authenticator app.';
    }
    if (lower.contains('csrf')) {
      return 'CSRF token rejected. Please go back and sign in again.';
    }
    return raw;
  }
}

class TotpVerifyResult {
  const TotpVerifyResult({
    required this.success,
    this.sessionId,
    this.sessionInfo,
    this.message,
    this.debugLog,
    this.errorCode,
  });

  final bool success;
  final String? sessionId;
  final Map<String, dynamic>? sessionInfo;
  final String? message;
  final TotpDebugLog? debugLog;
  final String? errorCode;
}
