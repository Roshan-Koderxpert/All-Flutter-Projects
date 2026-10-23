import 'package:http/http.dart' as http;

/// Keeps Odoo `session_id` in sync across a multi-step login / TOTP flow.
class OdooHttpSession {
  OdooHttpSession([String? sessionId]) : _sessionId = sessionId;

  String? _sessionId;

  String? get sessionId => _sessionId;

  void setSessionId(String? sessionId) {
    if (sessionId != null && sessionId.isNotEmpty) {
      _sessionId = sessionId;
    }
  }

  Map<String, String> get cookieHeader {
    final id = _sessionId;
    if (id == null || id.isEmpty) return const {};
    return {'Cookie': 'session_id=$id'};
  }

  static String? parseSessionId(Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return null;

    // http may merge multiple Set-Cookie values; take the last session_id.
    String? last;
    for (final match in RegExp(r'session_id=([^;,\s]+)').allMatches(setCookie)) {
      last = match.group(1);
    }
    return last;
  }

  void absorbCookies(Map<String, String> headers) {
    final parsed = parseSessionId(headers);
    if (parsed != null && parsed.isNotEmpty) {
      _sessionId = parsed;
    }
  }

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final response = await http
        .get(uri, headers: {...cookieHeader, ...?headers})
        .timeout(timeout);
    absorbCookies(response.headers);
    return response;
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final response = await http
        .post(uri, headers: {...cookieHeader, ...?headers}, body: body)
        .timeout(timeout);
    absorbCookies(response.headers);
    return response;
  }

  Future<http.Response> send(
    http.Request request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    request.headers.addAll(cookieHeader);
    final client = http.Client();
    try {
      final streamed = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      absorbCookies(response.headers);
      return response;
    } finally {
      client.close();
    }
  }
}
