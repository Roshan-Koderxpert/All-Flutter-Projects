import 'dart:io';
import '../../core/constants/api_constants.dart';
import '../../core/services/network_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/logger.dart';

class ApiProvider {
  final NetworkService _network;
  final StorageService _storage;

  ApiProvider(this._network, this._storage);

  // ── Fetch database list ───────────────────────
  Future<ApiResponse<List<String>>> fetchDatabases() async {
    try {
      final data = await _network.jsonRpc(
        endpoint: ApiConstants.dbList,
        params: {},
      );

      if (data.containsKey('error')) {
        final error = data['error'] as Map<String, dynamic>;
        final message = error['data']?['message'] ??
            error['message'] ??
            'Failed to fetch databases';
        AppLogger.error(message.toString(), tag: 'API');
        return ApiResponse.error(message.toString());
      }

      final result = data['result'];
      if (result == null) {
        return ApiResponse.error('No databases found on this server.');
      }

      final databases = List<String>.from(result as List);
      AppLogger.success('Databases: $databases', tag: 'API');
      return ApiResponse.success(databases);
    } on SocketException {
      return ApiResponse.error(
          'Cannot reach server. Check URL and internet connection.');
    } on HandshakeException {
      return ApiResponse.error('SSL error. Cannot establish secure connection.');
    } on FormatException {
      return ApiResponse.error('Invalid response from server.');
    } catch (e) {
      AppLogger.error('fetchDatabases error: $e', tag: 'API');
      return ApiResponse.error('Connection failed. Please try again.');
    }
  }

  // ── Authenticate with Odoo ────────────────────
  Future<ApiResponse<Map<String, dynamic>>> authenticate({
    required String db,
    required String login,
    required String password,
  }) async {
    try {
      final data = await _network.jsonRpc(
        endpoint: ApiConstants.authenticate,
        params: {
          'db':       db,
          'login':    login,
          'password': password,
        },
      );

      if (data.containsKey('error')) {
        final error = data['error'];
        String message = 'Authentication failed';
        if (error is Map<String, dynamic>) {
          final dataMap = error['data'];
          if (dataMap is Map<String, dynamic>) {
            message = dataMap['message']?.toString() ??
                dataMap['name']?.toString() ??
                error['message']?.toString() ??
                message;
          } else {
            message = error['message']?.toString() ?? message;
          }
        } else {
          message = error.toString();
        }
        message = _normalizeAuthErrorMessage(message);
        AppLogger.error('Auth error: $message', tag: 'API');
        return ApiResponse.error(message);
      }

      final result = data['result'];

      if (result == null) {
        AppLogger.warning('Auth result is null', tag: 'API');
        return ApiResponse.error('Invalid username or password.');
      }

      if (result is! Map) {
        AppLogger.warning('Unexpected auth result type: ${result.runtimeType}',
            tag: 'API');
        return ApiResponse.error('Invalid username or password.');
      }

      final map = Map<String, dynamic>.from(result);
      final uid = map['uid'];

      // uid: false without a JSON error key = TOTP is required.
      // In Odoo 16+, wrong credentials raise AccessDenied which becomes
      // the error field above, so reaching here with uid=false means 2FA.
      if (uid == false || uid == null) {
        AppLogger.warning('uid=false (no error) — TOTP required', tag: 'API');
        return ApiResponse.totpRequired();
      }

      final uidInt = uid is int ? uid : (uid is num ? uid.toInt() : null);
      if (uidInt == null || uidInt <= 0) {
        AppLogger.warning('Invalid credentials (uid=$uid)', tag: 'API');
        return ApiResponse.error('Invalid username or password.');
      }

      AppLogger.success(
        'Auth OK: uid=$uidInt name=${map['name']}',
        tag: 'API',
      );
      return ApiResponse.success(map);
    } on StateError catch (e) {
      AppLogger.error('authenticate: $e', tag: 'API');
      return ApiResponse.error(e.message);
    } on SocketException {
      return ApiResponse.error(
          'Cannot reach server. Check URL and internet connection.');
    } on HandshakeException {
      return ApiResponse.error('SSL error. Cannot establish secure connection.');
    } on FormatException {
      return ApiResponse.error('Invalid response from server.');
    } catch (e) {
      AppLogger.error('authenticate error: $e', tag: 'API');
      return ApiResponse.error('Connection failed. Please try again.');
    }
  }

  String _normalizeAuthErrorMessage(String rawMessage) {
    final message = rawMessage.trim();
    final normalized = message.toLowerCase();

    if (_looksLikeInvalidCredentials(normalized)) {
      return 'Invalid username or password.';
    }
    return message.isEmpty ? 'Authentication failed.' : message;
  }

  // ── Verify TOTP code (2FA) ────────────────────
  /// Called after authenticate returns totpRequired.
  /// The pre-auth session cookie must already be set in [NetworkService].
  Future<ApiResponse<Map<String, dynamic>>> verifyTotp({
    required String code,
  }) async {
    try {
      final data = await _network.jsonRpc(
        endpoint: ApiConstants.totpCheck,
        params: {'totp_token': code.trim()},
      );

      if (data.containsKey('error')) {
        final error = data['error'];
        String message = 'Invalid authentication code';
        if (error is Map<String, dynamic>) {
          final dataMap = error['data'];
          if (dataMap is Map<String, dynamic>) {
            message = dataMap['message']?.toString() ??
                error['message']?.toString() ??
                message;
          } else {
            message = error['message']?.toString() ?? message;
          }
        }
        AppLogger.error('TOTP error: $message', tag: 'API');
        return ApiResponse.error(message);
      }

      final result = data['result'];
      if (result == null) {
        return ApiResponse.error('Invalid authentication code.');
      }

      final map = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      AppLogger.success('TOTP verified', tag: 'API');
      return ApiResponse.success(map);
    } on SocketException {
      return ApiResponse.error(
          'Cannot reach server. Check URL and internet connection.');
    } on HandshakeException {
      return ApiResponse.error('SSL error. Cannot establish secure connection.');
    } on FormatException {
      return ApiResponse.error('Invalid response from server.');
    } catch (e) {
      AppLogger.error('verifyTotp error: $e', tag: 'API');
      return ApiResponse.error('Verification failed. Please try again.');
    }
  }

  // ── Get current session info ──────────────────
  Future<ApiResponse<Map<String, dynamic>>> getSessionInfo() async {
    try {
      final data = await _network.jsonRpc(
        endpoint: ApiConstants.sessionInfo,
        params: {},
      );

      if (data.containsKey('error')) {
        return ApiResponse.error('Failed to get session info.');
      }

      final result = data['result'];
      if (result == null || result is! Map) {
        return ApiResponse.error('Invalid session response.');
      }

      return ApiResponse.success(Map<String, dynamic>.from(result));
    } catch (e) {
      AppLogger.error('getSessionInfo error: $e', tag: 'API');
      return ApiResponse.error('Failed to get session info.');
    }
  }

  bool _looksLikeInvalidCredentials(String message) {
    return message.contains('access denied') ||
        message.contains('wrong login') ||
        message.contains('invalid login') ||
        message.contains('invalid password') ||
        message.contains('incorrect password') ||
        message.contains('login failed') ||
        message.contains('authentication failed') ||
        message.contains('bad credentials') ||
        message.contains('nonetype');
  }

  /// Odoo `/web/dataset/call_kw` — uses `session_id` cookie from [NetworkService].
  Future<ApiResponse<dynamic>> callKw({
    required String model,
    required String method,
    List<dynamic> args = const [],
    Map<String, dynamic> kwargs = const {},
  }) async {
    try {
      final mergedKwargs = Map<String, dynamic>.from(kwargs);
      final context = (mergedKwargs['context'] is Map)
          ? Map<String, dynamic>.from(mergedKwargs['context'] as Map)
          : <String, dynamic>{};
      final selectedLang = _storage.selectedLanguageCode.trim();
      if (selectedLang.isNotEmpty && context['lang'] == null) {
        context['lang'] = selectedLang;
      }
      final selectedCompanyIds = _storage.selectedCompanyIds;
      if (selectedCompanyIds.isNotEmpty &&
          context['allowed_company_ids'] == null) {
        context['allowed_company_ids'] = selectedCompanyIds;
        context.putIfAbsent('company_id', () => selectedCompanyIds.first);
      }
      if (context.isNotEmpty) {
        mergedKwargs['context'] = context;
      }

      final data = await _network.jsonRpc(
        endpoint: ApiConstants.callKw,
        params: {
          'model': model,
          'method': method,
          'args': args,
          'kwargs': mergedKwargs,
        },
      );

      if (data.containsKey('error')) {
        final error = data['error'];
        String message = 'Odoo request failed';
        if (error is Map<String, dynamic>) {
          final dataMap = error['data'];
          if (dataMap is Map<String, dynamic>) {
            message = dataMap['message']?.toString() ??
                dataMap['name']?.toString() ??
                error['message']?.toString() ??
                message;
          } else {
            message = error['message']?.toString() ?? message;
          }
        } else {
          message = error.toString();
        }
        AppLogger.error('call_kw error: $message', tag: 'API');
        return ApiResponse.error(message);
      }

      final result = data['result'];
      return ApiResponse.success(result);
    } on StateError catch (e) {
      AppLogger.error('call_kw: $e', tag: 'API');
      return ApiResponse.error(e.message);
    } on SocketException {
      return ApiResponse.error(
          'Cannot reach server. Check URL and internet connection.');
    } on HandshakeException {
      return ApiResponse.error('SSL error. Cannot establish secure connection.');
    } on FormatException {
      return ApiResponse.error('Invalid response from server.');
    } catch (e) {
      AppLogger.error('call_kw error: $e', tag: 'API');
      return ApiResponse.error('Connection failed. Please try again.');
    }
  }
}

// ── Generic response wrapper ──────────────────
class ApiResponse<T> {
  final bool success;
  final bool totpRequired;
  final T? data;
  final String? error;

  const ApiResponse.success(this.data)
      : success = true,
        totpRequired = false,
        error = null;

  const ApiResponse.error(this.error)
      : success = false,
        totpRequired = false,
        data = null;

  const ApiResponse.totpRequired()
      : success = false,
        totpRequired = true,
        data = null,
        error = null;
}