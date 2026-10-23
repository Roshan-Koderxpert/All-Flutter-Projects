import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/logger.dart';

class StorageService extends GetxService {
  static StorageService get to => Get.find();

  late final GetStorage _box;

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUsername   = 'username';
  static const String _keyUserRole   = 'user_role';
  static const String _keyUserId     = 'user_id';
  static const String _keyDb         = 'selected_db';
  static const String _keyServerUrl  = 'server_url';
  static const String _keySessionId  = 'session_id';
  static const String _keySelectedCompanyIds = 'selected_company_ids';
  static const String _keySelectedLanguageCode = 'selected_language_code';
  static const String _keyThemeMode = 'theme_mode';

  // ── Called automatically by GetX after put() ──
  @override
  void onInit() {
    super.onInit();
    _box = GetStorage();
    AppLogger.success('StorageService initialized', tag: 'STORAGE');
  }

  // ── Getters ───────────────────────────────────
  bool   get isLoggedIn => _box.read<bool>(_keyIsLoggedIn)   ?? false;
  String get username   => _box.read<String>(_keyUsername)   ?? '';
  String get userRole   => _box.read<String>(_keyUserRole)   ?? 'technician';
  String get userId     => _box.read<String>(_keyUserId)     ?? '';
  String get selectedDb => _box.read<String>(_keyDb)         ?? '';
  String get serverUrl  => _box.read<String>(_keyServerUrl)  ?? '';
  String get sessionId  => _box.read<String>(_keySessionId)  ?? '';
  String get selectedLanguageCode =>
      _box.read<String>(_keySelectedLanguageCode) ?? 'en_US';
  String get themeMode => _box.read<String>(_keyThemeMode) ?? 'light';
  List<int> get selectedCompanyIds {
    final raw = _box.read(_keySelectedCompanyIds);
    if (raw is List) {
      return raw
          .map((e) {
            if (e is int) return e;
            if (e is num) return e.toInt();
            return int.tryParse(e.toString());
          })
          .whereType<int>()
          .toList();
    }
    return const <int>[];
  }

  // ── Save session ──────────────────────────────
  Future<void> saveLoginSession({
    required String username,
    required String userId,
    required String role,
    required String db,
    required String serverUrl,
    String? odooSessionId,
    String? selectedLanguageCode,
  }) async {
    await _box.write(_keyIsLoggedIn, true);
    await _box.write(_keyUsername,   username);
    await _box.write(_keyUserId,     userId);
    await _box.write(_keyUserRole,   role);
    await _box.write(_keyDb,         db);
    await _box.write(_keyServerUrl,  serverUrl);
    if (odooSessionId != null && odooSessionId.trim().isNotEmpty) {
      await _box.write(_keySessionId, odooSessionId.trim());
    }
    if (selectedLanguageCode != null && selectedLanguageCode.trim().isNotEmpty) {
      await _box.write(_keySelectedLanguageCode, selectedLanguageCode.trim());
    }
    AppLogger.success('Session saved: $username @ $db', tag: 'STORAGE');
  }

  // ── Clear session ─────────────────────────────
  Future<void> clearSession() async {
    await _box.remove(_keyIsLoggedIn);
    await _box.remove(_keyUsername);
    await _box.remove(_keyUserId);
    await _box.remove(_keyUserRole);
    await _box.remove(_keyDb);
    await _box.remove(_keyServerUrl);
    await _box.remove(_keySessionId);
    await _box.remove(_keySelectedCompanyIds);
    await _box.remove(_keySelectedLanguageCode);
    await _box.remove(_keyThemeMode);
    AppLogger.info('Session cleared', tag: 'STORAGE');
  }

  Future<void> saveSelectedCompanyIds(List<int> ids) async {
    await _box.write(_keySelectedCompanyIds, ids);
  }

  Future<void> saveSelectedLanguageCode(String code) async {
    await _box.write(_keySelectedLanguageCode, code);
  }

  Future<void> saveThemeMode(String mode) async {
    await _box.write(_keyThemeMode, mode);
  }

  // ── Generic ───────────────────────────────────
  T?           read<T>(String key)              => _box.read<T>(key);
  Future<void> write(String key, dynamic value) => _box.write(key, value);
  Future<void> remove(String key)               => _box.remove(key);
  Future<void> clearAll()                       => _box.erase();
}