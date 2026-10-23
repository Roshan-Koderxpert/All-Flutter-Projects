import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:odoo_rpc/odoo_rpc.dart';

import 'odoo_http_session.dart';
import 'odoo_session_parser.dart';
import 'odoo_totp_service.dart';

/// Per-employee self-service features the admin enables in Odoo
/// (`hr.employee.mobile_access_*`). Must match the backend `MOBILE_ACCESS_FEATURES`.
const List<String> kMobileAccessFeatures = [
  'attendance',
  'leave',
  'timesheet',
  'payslip',
  'expense',
  'directory',
];

/// Successful employee sign-in: a session (running as the shared predefined
/// user), the `hr.employee` id to scope every screen to, and the feature flags
/// the admin granted this employee.
class EmployeeLoginResult {
  const EmployeeLoginResult({
    required this.session,
    required this.employeeId,
    required this.mobileAccess,
    this.employeeName,
    this.companyId,
  });

  final OdooSession session;
  final int employeeId;
  final String? employeeName;
  final int? companyId;

  /// feature -> allowed. Keys are from [kMobileAccessFeatures].
  final Map<String, bool> mobileAccess;

  bool featureAllowed(String feature) => mobileAccess[feature] ?? false;
}

/// Thrown when employee sign-in fails. [message] is shown to the user.
class EmployeeAuthException implements Exception {
  const EmployeeAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Signs an employee in through the module's mobile endpoint
/// `/hr_attendance_gps/mobile/employee/login`.
///
/// The endpoint validates the employee's own credentials, signs the request
/// session in as the shared predefined Odoo user, and returns the matching
/// `employee_id` plus that employee's feature rights. We then read
/// `session_info` (as the shared user) to build a normal [OdooSession] the rest
/// of the app already knows how to use.
class EmployeeAuthService {
  EmployeeAuthService._();

  static const String loginPath = '/hr_attendance_gps/employee_login';
  static const String forgotPasswordPath =
      '/hr_attendance_gps/employee_forgot_password';
  static const String loginConfigPath =
      '/hr_attendance_gps/mobile_login_config';

  static String _jsonRpcId() =>
      sha1.convert(utf8.encode(DateTime.now().toString())).toString();

  /// Binds [session] to [db] before calling a public module endpoint.
  ///
  /// Public routes carry no session, so on a multi-database server Odoo
  /// resolves them against whatever database its dbfilter guesses — if that
  /// guess lacks hr_attendance_gps, the route 404s even though the module is
  /// installed on the selected db. `GET /web/login?db=` makes `ensure_db()`
  /// stamp the db into a session cookie, so the next call routes correctly.
  /// Best-effort: any failure here just leaves the old behavior.
  static Future<void> _bindSessionToDb(
    OdooHttpSession session,
    String baseUrl,
    String db,
  ) async {
    if (db.isEmpty) return;
    try {
      final request = http.Request(
        'GET',
        Uri.parse('$baseUrl/web/login').replace(queryParameters: {'db': db}),
      )..followRedirects = false; // the Set-Cookie rides on the 302 itself
      await session.send(request, timeout: const Duration(seconds: 10));
    } catch (_) {
      // Ignore — the endpoint call below surfaces any real problem.
    }
  }

  static Future<EmployeeLoginResult> login({
    required String baseUrl,
    required String db,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl$loginPath');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'call',
      // Endpoint expects `login` + `password`; `db` is ignored (**kw) but kept
      // harmless for potential multi-db routing.
      'params': {'db': db, 'login': email, 'password': password},
      'id': _jsonRpcId(),
    });

    final httpSession = OdooHttpSession();
    await _bindSessionToDb(httpSession, baseUrl, db);
    final response = await httpSession.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
      timeout: const Duration(seconds: 20),
    );

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // A non-JSON body usually means the endpoint isn't deployed yet (404 HTML).
      if (response.statusCode == 404) {
        throw const EmployeeAuthException(
          'Employee sign-in is not available on this server yet. Please contact HR.',
          code: 'endpoint_missing',
        );
      }
      throw const EmployeeAuthException('Unexpected response from the server.');
    }

    if (decoded['error'] != null) {
      throw const EmployeeAuthException('Could not sign in. Please try again.');
    }

    final result = decoded['result'];
    if (result is! Map) {
      throw const EmployeeAuthException('Unexpected response from the server.');
    }
    final map = Map<String, dynamic>.from(result);

    if (map['success'] != true) {
      final code = map['error']?.toString();
      // The endpoint returns a ready, localized `message`; prefer it.
      final serverMessage = map['message']?.toString();
      throw EmployeeAuthException(
        (serverMessage != null && serverMessage.isNotEmpty)
            ? serverMessage
            : _messageForCode(code),
        code: code,
      );
    }

    final employeeId = map['employee_id'];
    if (employeeId is! int) {
      throw const EmployeeAuthException(
        'Signed in, but no employee was linked to these credentials.',
      );
    }

    // The response set the session cookie; turn it into a full session.
    final sessionId = httpSession.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      throw const EmployeeAuthException(
        'The server did not return a session. Please contact HR.',
      );
    }

    final info = await OdooTotpService.getSessionInfo(baseUrl, sessionId);
    if (!OdooSessionParser.isAuthenticated(info)) {
      throw const EmployeeAuthException(
        'Signed in, but the session could not be started.',
      );
    }
    final session = OdooSessionParser.fromSessionInfo(
      info,
      fallbackSessionId: sessionId,
    );

    return EmployeeLoginResult(
      session: session,
      employeeId: employeeId,
      employeeName: map['name']?.toString(),
      companyId: map['company_id'] is int ? map['company_id'] as int : null,
      mobileAccess: _parseMobileAccess(map['access_rights']),
    );
  }

  /// Whether Employee sign-in should be offered on the login screen.
  ///
  /// Backed by "Restrict Mobile App Access" (`res.company
  /// .hr_mobile_app_restricted`) via the public endpoint
  /// [loginConfigPath], which the app can reach before any session exists.
  /// Expected response: `{success: true, employee_login_enabled: bool}`.
  ///
  /// **Fails open** (returns `true`): if the endpoint isn't deployed, the
  /// server is unreachable, or the response is malformed, the login screen
  /// keeps today's dual-mode behavior — nobody is locked out by a probe.
  static Future<bool> fetchEmployeeLoginEnabled({
    required String baseUrl,
    required String db,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$loginConfigPath');
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {'db': db},
        'id': _jsonRpcId(),
      });

      final httpSession = OdooHttpSession();
      await _bindSessionToDb(httpSession, baseUrl, db);
      final response = await httpSession.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
        timeout: const Duration(seconds: 10),
      );

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['error'] != null) return true;
      final result = decoded['result'];
      if (result is! Map || result['success'] != true) return true;

      // `employee_login_enabled` preferred; `restricted` accepted as alias.
      final enabled =
          result['employee_login_enabled'] ?? result['restricted'];
      return enabled is bool ? enabled : true;
    } catch (_) {
      return true;
    }
  }

  /// Requests a password-reset email for the employee credential [email].
  ///
  /// The endpoint always answers with the same generic message whether or not
  /// the email is registered (anti-enumeration), so a successful call here
  /// does not confirm the account exists — that is by design. Returns the
  /// message to show the user; throws [EmployeeAuthException] only for real
  /// failures (empty email, endpoint missing, network error).
  static Future<String> requestPasswordReset({
    required String baseUrl,
    required String email,
    String db = '',
  }) async {
    final uri = Uri.parse('$baseUrl$forgotPasswordPath');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {'login': email},
      'id': _jsonRpcId(),
    });

    final httpSession = OdooHttpSession();
    await _bindSessionToDb(httpSession, baseUrl, db);
    final response = await httpSession.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
      timeout: const Duration(seconds: 20),
    );

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      if (response.statusCode == 404) {
        throw const EmployeeAuthException(
          'Password reset isn\'t available on this server yet. Please contact HR.',
          code: 'endpoint_missing',
        );
      }
      throw const EmployeeAuthException('Unexpected response from the server.');
    }

    if (decoded['error'] != null) {
      throw const EmployeeAuthException(
        'Could not request a reset link. Please try again.',
      );
    }

    final result = decoded['result'];
    if (result is! Map) {
      throw const EmployeeAuthException('Unexpected response from the server.');
    }
    final map = Map<String, dynamic>.from(result);
    final message = map['message']?.toString();

    if (map['success'] != true) {
      throw EmployeeAuthException(
        (message != null && message.isNotEmpty)
            ? message
            : 'Enter your login email.',
        code: map['error']?.toString(),
      );
    }

    return (message != null && message.isNotEmpty)
        ? message
        : 'If that email is registered, we\'ve sent a link to reset the password.';
  }

  /// Reads the `{feature: bool}` map. If the server omits it (older endpoint),
  /// default every known feature to allowed so nothing is hidden by surprise —
  /// matching the backend's all-on default.
  static Map<String, bool> _parseMobileAccess(dynamic raw) {
    final result = <String, bool>{};
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    for (final feature in kMobileAccessFeatures) {
      final value = map[feature];
      result[feature] = value is bool ? value : (raw is Map ? false : true);
    }
    return result;
  }

  static String _messageForCode(String? code) {
    switch (code) {
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'missing_credentials':
        return 'Enter an email and password.';
      case 'not_configured':
        return 'Employee sign-in is not set up on the server. Please contact HR.';
      default:
        return 'Could not sign in. Please try again.';
    }
  }
}
