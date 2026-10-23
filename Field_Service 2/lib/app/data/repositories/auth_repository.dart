import '../../core/constants/app_strings.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/network_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/logger.dart';
import '../models/user_model.dart';
import '../providers/api_provider.dart';

// ── Result wrapper ────────────────────────────
class AuthResult {
  final bool success;
  final bool totpRequired;
  final bool moduleNotInstalled;
  final UserModel? user;
  final String? errorMessage;

  const AuthResult.success(this.user)
      : success = true,
        totpRequired = false,
        moduleNotInstalled = false,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage)
      : success = false,
        totpRequired = false,
        moduleNotInstalled = false,
        user = null;

  const AuthResult.totpRequired()
      : success = false,
        totpRequired = true,
        moduleNotInstalled = false,
        user = null,
        errorMessage = null;

  const AuthResult.moduleNotInstalled()
      : success = false,
        totpRequired = false,
        moduleNotInstalled = true,
        user = null,
        errorMessage = null;
}

// ── Database fetch result ─────────────────────
class DbFetchResult {
  final bool success;
  final List<String> databases;
  final String? errorMessage;

  const DbFetchResult.success(this.databases)
      : success = true,
        errorMessage = null;

  const DbFetchResult.failure(this.errorMessage)
      : success = false,
        databases = const [];
}

class AuthRepository {
  static const List<String> _fieldServiceModuleNames = <String>[
    'field_service',
    'industry_fsm',
    'fieldservice',
  ];

  final ApiProvider _apiProvider;
  final StorageService _storage;
  final NetworkService _network;
  final ConnectivityService _connectivity;

  AuthRepository(
    this._apiProvider,
    this._storage,
    this._network,
    this._connectivity,
  );

  // ── Step 1: Set server URL + fetch databases ──
  Future<DbFetchResult> fetchDatabases({
    required String protocol,
    required String host,
  }) async {
    if (host.trim().isEmpty) {
      return const DbFetchResult.failure('Please enter a server address.');
    }

    if (!_connectivity.isOnline.value) {
      return DbFetchResult.failure(AppStrings.errorNoInternet);
    }

    // Set base URL on the Dio client
    _network.setBaseUrl(protocol, host.trim());

    AppLogger.info('Fetching databases from $protocol$host', tag: 'AUTH_REPO');

    final response = await _apiProvider.fetchDatabases();

    if (!response.success || response.data == null) {
      return DbFetchResult.failure(
        response.error ?? 'Could not fetch databases from server.',
      );
    }

    if (response.data!.isEmpty) {
      return const DbFetchResult.failure(
        'No databases found on this server.',
      );
    }

    return DbFetchResult.success(response.data!);
  }

  // ── Step 2: Authenticate with Odoo ───────────
  Future<AuthResult> login({
    required String db,
    required String username,
    required String password,
  }) async {
    AppLogger.info('Login: $username @ $db', tag: 'AUTH_REPO');

    if (!_connectivity.isOnline.value) {
      return AuthResult.failure(AppStrings.errorNoInternet);
    }

    _network.clearSession(); // ← ADD THIS LINE


    final response = await _apiProvider.authenticate(
      db:       db,
      login:    username.trim(),
      password: password,
    );

    if (response.totpRequired) {
      AppLogger.info('TOTP required for $username', tag: 'AUTH_REPO');
      return const AuthResult.totpRequired();
    }

    if (!response.success || response.data == null) {
      return AuthResult.failure(
        response.error ?? 'Login failed. Please try again.',
      );
    }

    // Parse Odoo session result into UserModel
    final UserModel user;
    try {
      user = UserModel.fromOdooSession(response.data!);
    } catch (e) {
      AppLogger.error('Session parse failed', tag: 'AUTH_REPO', error: e);
      return const AuthResult.failure(
        'Unexpected server response. Please try again.',
      );
    }

    if (user.uid <= 0) {
      return const AuthResult.failure('Invalid username or password.');
    }

    if (!await isFieldServiceModuleInstalled()) {
      _network.clearSession();
      AppLogger.warning(
        'Field Service module not installed on $db',
        tag: 'AUTH_REPO',
      );
      return const AuthResult.moduleNotInstalled();
    }

    // Persist session locally
    await _storage.saveLoginSession(
      username:  user.username,
      userId:    user.uid.toString(),
      role:      user.isSystem ? 'admin' : 'technician',
      db:        db,
      serverUrl: _network.baseUrl ?? '',
      odooSessionId: _network.sessionId,
      selectedLanguageCode: user.lang,
    );

    AppLogger.success(
      'Login success: ${user.name} (uid=${user.uid})',
      tag: 'AUTH_REPO',
    );

    return AuthResult.success(user);
  }

  // ── Step 3: Verify TOTP code (when 2FA is enabled) ───
  Future<AuthResult> verifyTotp({
    required String code,
    required String db,
  }) async {
    AppLogger.info('Verifying TOTP', tag: 'AUTH_REPO');

    if (!_connectivity.isOnline.value) {
      return AuthResult.failure(AppStrings.errorNoInternet);
    }

    final totpResponse = await _apiProvider.verifyTotp(code: code);

    if (!totpResponse.success) {
      final msg = totpResponse.error ?? 'Invalid authentication code.';
      AppLogger.error('TOTP failed: $msg', tag: 'AUTH_REPO');
      return AuthResult.failure(_normalizeToTpError(msg));
    }

    // Fetch full session data now that the session is fully authenticated.
    final sessionResponse = await _apiProvider.getSessionInfo();

    if (!sessionResponse.success || sessionResponse.data == null) {
      return const AuthResult.failure(
        'Authentication succeeded but could not retrieve session. Please try again.',
      );
    }

    final UserModel user;
    try {
      user = UserModel.fromOdooSession(sessionResponse.data!);
    } catch (e) {
      AppLogger.error('Session parse failed after TOTP', tag: 'AUTH_REPO', error: e);
      return const AuthResult.failure(
        'Unexpected server response. Please try again.',
      );
    }

    if (user.uid <= 0) {
      return const AuthResult.failure('Authentication failed. Please try again.');
    }

    if (!await isFieldServiceModuleInstalled()) {
      _network.clearSession();
      AppLogger.warning(
        'Field Service module not installed on $db (after TOTP)',
        tag: 'AUTH_REPO',
      );
      return const AuthResult.moduleNotInstalled();
    }

    await _storage.saveLoginSession(
      username:  user.username,
      userId:    user.uid.toString(),
      role:      user.isSystem ? 'admin' : 'technician',
      db:        db,
      serverUrl: _network.baseUrl ?? '',
      odooSessionId: _network.sessionId,
      selectedLanguageCode: user.lang,
    );

    AppLogger.success('TOTP verified: ${user.name} (uid=${user.uid})', tag: 'AUTH_REPO');
    return AuthResult.success(user);
  }

  /// Returns true when the selected database has Field Service / FSM available.
  Future<bool> isFieldServiceModuleInstalled() async {
    try {
      final moduleRes = await _apiProvider.callKw(
        model: 'ir.module.module',
        method: 'search_count',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['name', 'in', _fieldServiceModuleNames],
            <dynamic>['state', '=', 'installed'],
          ],
        ],
      );
      if (moduleRes.success && moduleRes.data is int) {
        if ((moduleRes.data as int) > 0) return true;
      }

      final modelRes = await _apiProvider.callKw(
        model: 'ir.model',
        method: 'search_count',
        args: <dynamic>[
          <dynamic>[<dynamic>['model', '=', 'fsm.order']],
        ],
      );
      if (modelRes.success && modelRes.data is int) {
        return (modelRes.data as int) > 0;
      }

      return false;
    } catch (e) {
      AppLogger.error(
        'isFieldServiceModuleInstalled error',
        tag: 'AUTH_REPO',
        error: e,
      );
      // On unexpected errors, do not block login (preserve existing behaviour).
      return true;
    }
  }

  String _normalizeToTpError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('totp') ||
        lower.contains('otp') ||
        lower.contains('token') ||
        lower.contains('code') ||
        lower.contains('invalid') ||
        lower.contains('expired') ||
        lower.contains('wrong')) {
      return 'Invalid or expired authentication code. Please try again.';
    }
    return message;
  }

  // ── Logout ────────────────────────────────────
  Future<void> logout() async {
    _network.clearSession();
    _network.clearBaseUrl();
    await _storage.clearSession();
    AppLogger.info('Logged out', tag: 'AUTH_REPO');
  }

  // ── Session check ─────────────────────────────
  bool get isLoggedIn => _storage.isLoggedIn;
  String get savedUsername => _storage.username;



  // ── Fetch logged-in user profile ──────────────
  Future<Map<String, dynamic>?> fetchProfile() async {
    final userId = int.tryParse(_storage.userId);
    if (userId == null || userId <= 0) return null;

    final res = await _apiProvider.callKw(
      model: 'res.users',
      method: 'read',
      args: [[userId]],
      kwargs: {'fields': ['name', 'image_128']},
    );

    if (res.success && res.data is List && (res.data as List).isNotEmpty) {
      final data = Map<String, dynamic>.from((res.data as List).first);
      final base = _network.baseUrl ?? '';
      final hasImage = data['image_128'] != null && data['image_128'] != false;
      data['image_url'] = hasImage
          ? '$base/web/image/res.users/$userId/image_128'
          : '';
      return data;
    }
    return null;
  }

  // ── Fetch companies for logged-in user ────────
  Future<List<Map<String, dynamic>>> fetchCompanies() async {
    final userId = int.tryParse(_storage.userId);
    if (userId == null || userId <= 0) return [];

    final userRes = await _apiProvider.callKw(
      model: 'res.users',
      method: 'read',
      args: [[userId]],
      kwargs: {'fields': ['company_ids', 'company_id']},
    );

    if (!userRes.success || userRes.data is! List || (userRes.data as List).isEmpty) {
      return [];
    }

    final userData = Map<String, dynamic>.from((userRes.data as List).first);
    final companyIds = List<int>.from(userData['company_ids'] ?? []);
    if (companyIds.isEmpty) return [];

    final currentId = userData['company_id'] is List
        ? (userData['company_id'] as List).first as int?
        : userData['company_id'] as int?;

    final namesRes = await _apiProvider.callKw(
      model: 'res.company',
      method: 'read',
      args: [companyIds],
      kwargs: {'fields': ['id', 'name']},
    );

    if (!namesRes.success || namesRes.data is! List) return [];

    return (namesRes.data as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      m['is_current'] = m['id'] == currentId;
      return m;
    }).toList();
  }

  Future<Map<String, dynamic>?> fetchMyProfileDetails() async {
    final userId = int.tryParse(_storage.userId);
    if (userId == null || userId <= 0) return null;

    try {
      final userFieldsRes = await _apiProvider.callKw(
        model: 'res.users',
        method: 'fields_get',
        args: const <dynamic>[],
        kwargs: const <String, dynamic>{},
      );
      final userFieldMap = userFieldsRes.success && userFieldsRes.data is Map
          ? Map<String, dynamic>.from(userFieldsRes.data as Map)
          : <String, dynamic>{};

      final wantedUserFields = <String>[
        'name',
        'image_128',
        'lang',
        'tz',
        'signature',
        'employee_id',
        'property_warehouse_id',
        'default_warehouse_id',
        'warehouse_id',
      ].where(userFieldMap.containsKey).toList();
      if (!wantedUserFields.contains('name')) wantedUserFields.add('name');
      if (!wantedUserFields.contains('image_128')) wantedUserFields.add('image_128');

      final userRes = await _apiProvider.callKw(
        model: 'res.users',
        method: 'read',
        args: <dynamic>[<int>[userId]],
        kwargs: <String, dynamic>{'fields': wantedUserFields},
      );
      if (!userRes.success || userRes.data is! List || (userRes.data as List).isEmpty) {
        return null;
      }
      final user = Map<String, dynamic>.from((userRes.data as List).first as Map);

      final tzOptions = _extractSelectionOptions(userFieldMap['tz']);
      Map<String, dynamic> employee = <String, dynamic>{};
      final employeeId = _m2oId(user['employee_id']);
      if (employeeId != null && employeeId > 0) {
        final empFieldsRes = await _apiProvider.callKw(
          model: 'hr.employee',
          method: 'fields_get',
          args: const <dynamic>[],
          kwargs: const <String, dynamic>{},
        );
        final empFieldMap = empFieldsRes.success && empFieldsRes.data is Map
            ? Map<String, dynamic>.from(empFieldsRes.data as Map)
            : <String, dynamic>{};
        final wantedEmpFields = <String>[
          'job_title',
          'mobile_phone',
          'work_phone',
          'work_email',
          'work_location',
          'parent_id',
          'coach_id',
        ].where(empFieldMap.containsKey).toList();
        if (wantedEmpFields.isNotEmpty) {
          final empRes = await _apiProvider.callKw(
            model: 'hr.employee',
            method: 'read',
            args: <dynamic>[<int>[employeeId]],
            kwargs: <String, dynamic>{'fields': wantedEmpFields},
          );
          if (empRes.success && empRes.data is List && (empRes.data as List).isNotEmpty) {
            employee = Map<String, dynamic>.from((empRes.data as List).first as Map);
          }
        }
      }

      String langLabel = '';
      final langCode = user['lang']?.toString().trim() ?? '';
      final languageOptions = <Map<String, String>>[];
      if (langCode.isNotEmpty) {
        final langRes = await _apiProvider.callKw(
          model: 'res.lang',
          method: 'search_read',
          args: <dynamic>[
            <dynamic>[<dynamic>['code', '=', langCode]],
          ],
          kwargs: const <String, dynamic>{'fields': <String>['name'], 'limit': 1},
        );
        if (langRes.success && langRes.data is List && (langRes.data as List).isNotEmpty) {
          final row = Map<String, dynamic>.from((langRes.data as List).first as Map);
          langLabel = row['name']?.toString() ?? '';
        }
      }
      final allLangRes = await _apiProvider.callKw(
        model: 'res.lang',
        method: 'search_read',
        args: <dynamic>[<dynamic>[]],
        kwargs: const <String, dynamic>{
          'fields': <String>['code', 'name'],
          'order': 'name asc',
          'limit': 300,
        },
      );
      if (allLangRes.success && allLangRes.data is List) {
        for (final row in allLangRes.data as List) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(row);
          final code = map['code']?.toString() ?? '';
          final name = map['name']?.toString() ?? code;
          if (code.trim().isEmpty) continue;
          languageOptions.add(<String, String>{'value': code, 'label': name});
        }
      }

      final warehouseOptions = <Map<String, dynamic>>[];
      final warehouseRes = await _apiProvider.callKw(
        model: 'stock.warehouse',
        method: 'search_read',
        args: <dynamic>[<dynamic>[]],
        kwargs: const <String, dynamic>{
          'fields': <String>['id', 'name'],
          'order': 'name asc',
          'limit': 300,
        },
      );
      if (warehouseRes.success && warehouseRes.data is List) {
        for (final row in warehouseRes.data as List) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(row);
          final id = _m2oId(map['id']) ?? (map['id'] is int ? map['id'] as int : null);
          if (id == null) continue;
          warehouseOptions.add(<String, dynamic>{
            'id': id,
            'name': map['name']?.toString() ?? 'Warehouse #$id',
          });
        }
      }

      final warehouseLabel = _m2oLabel(user['property_warehouse_id']).isNotEmpty
          ? _m2oLabel(user['property_warehouse_id'])
          : _m2oLabel(user['default_warehouse_id']).isNotEmpty
              ? _m2oLabel(user['default_warehouse_id'])
              : _m2oLabel(user['warehouse_id']);
      final warehouseId = _m2oId(user['property_warehouse_id']) ??
          _m2oId(user['default_warehouse_id']) ??
          _m2oId(user['warehouse_id']);

      final base = _network.baseUrl ?? '';
      final hasImage = user['image_128'] != null && user['image_128'] != false;
      return <String, dynamic>{
        'user_id': userId,
        'employee_id': employeeId,
        'name': user['name']?.toString() ?? '',
        'image_url': hasImage ? '$base/web/image/res.users/$userId/image_128' : '',
        'position': employee['job_title']?.toString() ?? '',
        'work_mobile': employee['mobile_phone']?.toString() ?? '',
        'work_phone': employee['work_phone']?.toString() ?? '',
        'work_email': employee['work_email']?.toString() ?? '',
        'work_location': employee['work_location']?.toString() ?? '',
        'manager': _m2oLabel(employee['parent_id']),
        'coach': _m2oLabel(employee['coach_id']),
        'language': langLabel.isNotEmpty ? langLabel : langCode,
        'language_code': langCode,
        'language_options': languageOptions,
        'time_zone': user['tz']?.toString() ?? '',
        'time_zone_options': tzOptions,
        'email_signature': _stripHtml(user['signature']?.toString() ?? ''),
        'email_signature_html': user['signature']?.toString() ?? '',
        'default_warehouse': warehouseLabel,
        'default_warehouse_id': warehouseId,
        'warehouse_options': warehouseOptions,
      };
    } catch (e) {
      AppLogger.error('fetchMyProfileDetails error', tag: 'AUTH_REPO', error: e);
      return null;
    }
  }

  int? _m2oId(dynamic v) {
    if (v is List && v.isNotEmpty) {
      final first = v.first;
      if (first is int) return first;
      if (first is num) return first.toInt();
      return int.tryParse(first.toString());
    }
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  String _m2oLabel(dynamic v) {
    if (v is List && v.length >= 2) return v[1]?.toString() ?? '';
    return '';
  }

  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    final noTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final decoded = noTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<Map<String, String>> _extractSelectionOptions(dynamic fieldDef) {
    if (fieldDef is! Map) return const <Map<String, String>>[];
    final selection = fieldDef['selection'];
    if (selection is! List) return const <Map<String, String>>[];
    final out = <Map<String, String>>[];
    for (final item in selection) {
      if (item is List && item.length >= 2) {
        final value = item[0]?.toString() ?? '';
        final label = item[1]?.toString() ?? value;
        if (value.trim().isEmpty) continue;
        out.add(<String, String>{'value': value, 'label': label});
      }
    }
    return out;
  }

  Future<bool> updateMyProfileDetails({
    required Map<String, dynamic> profile,
  }) async {
    final userId = int.tryParse(_storage.userId);
    if (userId == null || userId <= 0) return false;
    final employeeId = _m2oId(profile['employee_id']);
    final userVals = <String, dynamic>{
      'lang': profile['language_code'],
      'tz': profile['time_zone'],
      'signature': profile['email_signature'] ?? '',
      if (profile['default_warehouse_id'] != null)
        'property_warehouse_id': profile['default_warehouse_id'],
    };
    final employeeVals = <String, dynamic>{
      'job_title': profile['position'] ?? '',
      'mobile_phone': profile['work_mobile'] ?? '',
      'work_phone': profile['work_phone'] ?? '',
      'work_email': profile['work_email'] ?? '',
      // 'work_location': profile['work_location'] ?? '',
    };
    final managerName = profile['manager']?.toString().trim() ?? '';
    final coachName = profile['coach']?.toString().trim() ?? '';
    if (managerName.isNotEmpty) {
      final managerId = await _findEmployeeIdByName(managerName);
      if (managerId != null) employeeVals['parent_id'] = managerId;
    }
    if (coachName.isNotEmpty) {
      final coachId = await _findEmployeeIdByName(coachName);
      if (coachId != null) employeeVals['coach_id'] = coachId;
    }
    final userWrite = await _apiProvider.callKw(
      model: 'res.users',
      method: 'write',
      args: <dynamic>[<int>[userId], userVals],
      kwargs: const <String, dynamic>{},
    );
    if (!userWrite.success) return false;
    if (employeeId != null && employeeId > 0) {
      final empWrite = await _apiProvider.callKw(
        model: 'hr.employee',
        method: 'write',
        args: <dynamic>[<int>[employeeId], employeeVals],
        kwargs: const <String, dynamic>{},
      );
      if (!empWrite.success) return false;
    }
    final langCode = profile['language_code']?.toString().trim();
    if (langCode != null && langCode.isNotEmpty) {
      await _storage.saveSelectedLanguageCode(langCode);
    }
    return true;
  }

  Future<int?> _findEmployeeIdByName(String name) async {
    final res = await _apiProvider.callKw(
      model: 'hr.employee',
      method: 'search_read',
      args: <dynamic>[
        <dynamic>[<dynamic>['name', '=ilike', name]],
      ],
      kwargs: const <String, dynamic>{'fields': <String>['id'], 'limit': 1},
    );
    if (!res.success || res.data is! List || (res.data as List).isEmpty) return null;
    final row = Map<String, dynamic>.from((res.data as List).first as Map);
    return _m2oId(row['id']) ?? (row['id'] is int ? row['id'] as int : null);
  }


}