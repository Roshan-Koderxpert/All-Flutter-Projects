import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../constants/api_constants.dart';
import '../utils/logger.dart';

class NetworkService extends GetxService {
  static NetworkService get to => Get.find();

  String? _sessionId;
  String? _baseUrl;

  String? get sessionId => _sessionId;
  String? get baseUrl => _baseUrl;

  late final HttpClient _client;

  @override
  void onInit() {
    super.onInit();
    _client = HttpClient();

    // Bypass SSL certificate errors in debug/profile
    if (!kReleaseMode) {
      _client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    }

    AppLogger.success('NetworkService initialized', tag: 'NETWORK');
  }

  // ── Set base URL ──────────────────────────────
  void setBaseUrl(String protocol, String host) {
    _baseUrl =
        '$protocol$host'.trimRight().replaceAll(RegExp(r'/$'), '');
    AppLogger.info('Base URL set: $_baseUrl', tag: 'NETWORK');
  }

  /// Restore Odoo base URL after app restart (from [StorageService.serverUrl]).
  void restoreBaseUrlFromStorage(String storedUrl) {
    final t = storedUrl.trim();
    if (t.isEmpty) return;
    _baseUrl = t.replaceAll(RegExp(r'/$'), '');
    AppLogger.info('Base URL restored from storage: $_baseUrl', tag: 'NETWORK');
  }

  void clearSession() {
    _sessionId = null;
    AppLogger.info('Session cleared', tag: 'NETWORK');
  }

  /// Restore Odoo `session_id` after app restart (see [StorageService.sessionId]).
  void setSessionId(String? id) {
    final t = id?.trim();
    _sessionId = (t == null || t.isEmpty) ? null : t;
    if (_sessionId != null) {
      AppLogger.info('Session ID restored from storage', tag: 'NETWORK');
    }
  }

  void clearBaseUrl() {
    _baseUrl = null;
    AppLogger.info('Base URL cleared', tag: 'NETWORK');
  }

  // ── Generic JSON-RPC POST using raw HttpClient ─
  // We use dart:io HttpClient directly to avoid Dio's
  // "header has more than one value" exception with
  // Odoo's multiple Set-Cookie headers
  Future<Map<String, dynamic>> jsonRpc({
    required String endpoint,
    required Map<String, dynamic> params,
  }) async {
    final base = _baseUrl;
    if (base == null || base.isEmpty) {
      throw StateError(
        'Server URL is not set. Fetch databases first before signing in.',
      );
    }

    final url = '$base$endpoint';
    AppLogger.info('→ POST $url', tag: 'NETWORK');

    final body = jsonEncode({
      'jsonrpc': ApiConstants.jsonrpc,
      'method':  ApiConstants.method,
      'id':      DateTime.now().millisecondsSinceEpoch,
      'params':  params,
    });

    final uri = Uri.parse(url);
    final request = await _client.postUrl(uri);

    // Headers
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (_sessionId != null) {
      request.headers.set(HttpHeaders.cookieHeader, 'session_id=$_sessionId');
    }

    request.add(utf8.encode(body));
    final response = await request.close();

    AppLogger.info('← ${response.statusCode} $url', tag: 'NETWORK');

    // ── Extract session_id from ALL Set-Cookie headers ──
    response.headers.forEach((name, values) {
      if (name.toLowerCase() == 'set-cookie') {
        for (final cookie in values) {
          if (cookie.contains('session_id=')) {
            final match = RegExp(r'session_id=([^;]+)').firstMatch(cookie);
            if (match != null) {
              _sessionId = match.group(1);
              AppLogger.info('Session ID: $_sessionId', tag: 'NETWORK');
            }
          }
        }
      }
    });

    // Read response body
    final responseBody = await response.transform(utf8.decoder).join();

    // ── Guard: proxy errors (504, 502, 503) return HTML, not JSON ──────────
    // Check Content-Type header first, then fall back to body sniffing.
    // This prevents a cryptic FormatException from jsonDecode on HTML pages.
    final contentType = response.headers.value(HttpHeaders.contentTypeHeader) ?? '';
    final bodyTrimmed = responseBody.trimLeft();
    final looksLikeJson = contentType.contains('application/json') ||
        bodyTrimmed.startsWith('{') ||
        bodyTrimmed.startsWith('[');

    if (!looksLikeJson) {
      // Strip HTML tags and truncate to produce a readable error message
      final stripped = responseBody
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final preview = stripped.length > 120
          ? '${stripped.substring(0, 120)}…'
          : stripped;
      AppLogger.warning(
        'Non-JSON response (HTTP ${response.statusCode}): $preview',
        tag: 'NETWORK',
      );
      throw HttpException(
        'Server returned HTTP ${response.statusCode}: $preview',
        uri: uri,
      );
    }

    return jsonDecode(responseBody) as Map<String, dynamic>;
  }

  @override
  void onClose() {
    _client.close();
    super.onClose();
  }
}