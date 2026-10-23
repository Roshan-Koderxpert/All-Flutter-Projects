import 'package:get_storage/get_storage.dart';

import '../../core/utils/auth_debug.dart';
import '../models/account_model.dart';

class AuthStorage {
  AuthStorage._();

  static final _box = GetStorage();

  static const _keyLoggedIn = 'is_logged_in';
  static const _keyAccounts = 'saved_accounts';
  static const _keyActiveAccountId = 'active_account_id';
  static const _keySelectedCompanyIds = 'selected_company_ids';

  static Future<bool> isLoggedIn() async {
    return _box.read<bool>(_keyLoggedIn) ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    await _box.write(_keyLoggedIn, value);
  }

  static Future<void> saveLogin({
    required String url,
    required String db,
    required int userId,
    required String sessionId,
    required String email,
    required String password,
    String loginMode = AccountModel.modeUser,
  }) async {
    await _box.write('login_url', url);
    await _box.write('login_db', db);
    await _box.write('login_user_id', userId);
    await _box.write('login_session_id', sessionId);
    await _box.write('login_email', email);
    await _box.write('login_password', password);
    await _box.write('login_mode', loginMode);
    await setLoggedIn(true);
    AuthDebug.log(
      'saveLogin',
      {
        'user': email,
        'db': db,
        'url': url,
        'userId': userId,
        'session': sessionId.isNotEmpty,
      },
    );
  }

  static Future<void> clearLogin() async {
    await _box.remove('login_url');
    await _box.remove('login_db');
    await _box.remove('login_user_id');
    await _box.remove('login_session_id');
    await _box.remove('login_email');
    await _box.remove('login_password');
    await _box.remove('login_mode');
    await setLoggedIn(false);
    AuthDebug.log('clearLogin');
  }

  static Future<bool> hasPersistedSession() async {
    return isLoggedIn();
  }

  static Future<bool> hasSavedAccounts() async {
    final accounts = await getAllAccounts();
    return accounts.isNotEmpty;
  }

  static Future<void> migrateLegacyLoginIfNeeded() async {
    final raw = _box.read<List<dynamic>>(_keyAccounts);
    if (raw != null && raw.isNotEmpty) return;

    final url = _box.read<String>('login_url');
    final db = _box.read<String>('login_db');
    final email = _box.read<String>('login_email');
    final password = _box.read<String>('login_password');
    final userId = _box.read<int>('login_user_id');
    final sessionId = _box.read<String>('login_session_id');

    if (url == null ||
        db == null ||
        email == null ||
        password == null ||
        userId == null) {
      return;
    }

    await _writeAccounts([
      AccountModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        url: url.trim(),
        database: db,
        username: email.trim(),
        password: password,
        userId: userId,
        sessionId: sessionId,
        isActive: await isLoggedIn(),
        lastLogin: DateTime.now(),
      ),
    ]);
    AuthDebug.log('migrateLegacyLoginIfNeeded', {'user': email});
  }

  static Future<List<AccountModel>> getAllAccounts() async {
    await migrateLegacyLoginIfNeeded();

    final raw = _box.read<List<dynamic>>(_keyAccounts);
    if (raw == null) return [];

    final accounts = <AccountModel>[];
    for (final entry in raw) {
      try {
        accounts.add(
          AccountModel.fromJson(Map<String, dynamic>.from(entry as Map)),
        );
      } catch (_) {
        // Skip corrupted entries instead of dropping the whole list.
      }
    }

    final deduped = _dedupeByIdentity(accounts);
    final sanitized = _sanitizeAccountSessions(deduped);
    final sorted = _sortByRecentLogin(sanitized);

    if (sorted.length != raw.length ||
        !_sameAccountOrder(accounts, sorted) ||
        accounts.length != sorted.length ||
        !_sameSessionState(accounts, sorted)) {
      await _writeAccounts(sorted);
    }

    return sorted;
  }

  static bool _sameSessionState(List<AccountModel> a, List<AccountModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].isActive != b[i].isActive) return false;
      if (a[i].sessionId != b[i].sessionId) return false;
      if (a[i].password != b[i].password) return false;
    }
    return true;
  }

  static bool _sameAccountOrder(List<AccountModel> a, List<AccountModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  static List<AccountModel> _sortByRecentLogin(List<AccountModel> accounts) {
    final sorted = List<AccountModel>.from(accounts);
    sorted.sort((a, b) {
      final aTime = a.lastLogin ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastLogin ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  /// Profile-only fields for the login screen — no session or password.
  static AccountModel toRememberedOnly(AccountModel account) {
    return account.copyWith(
      isActive: false,
      sessionId: null,
      password: '',
    );
  }

  /// When logged in, only the account matching [login_*] keys may keep credentials.
  static List<AccountModel> _sanitizeAccountSessions(
    List<AccountModel> accounts,
  ) {
    if (accounts.isEmpty) return accounts;

    final loggedIn = _box.read<bool>(_keyLoggedIn) ?? false;
    if (!loggedIn) {
      var changed = false;
      final remembered = accounts.map((account) {
        if (account.isActive ||
            account.hasStoredSession ||
            account.password.isNotEmpty) {
          changed = true;
          return toRememberedOnly(account);
        }
        return account;
      }).toList();
      if (changed) {
        AuthDebug.log('sanitizeAccountSessions:signedOutRememberOnly');
      }
      return remembered;
    }

    final loginUrl = _box.read<String>('login_url');
    final loginDb = _box.read<String>('login_db');
    final loginEmail = _box.read<String>('login_email');
    final activeId = _box.read<String>(_keyActiveAccountId);

    AccountModel? allowed;
    if (loginUrl != null && loginDb != null && loginEmail != null) {
      for (final account in accounts) {
        if (account.matchesCredentials(
          url: loginUrl,
          database: loginDb,
          username: loginEmail,
        )) {
          allowed = account;
          break;
        }
      }
    }

    allowed ??= activeId == null
        ? null
        : accounts.cast<AccountModel?>().firstWhere(
              (account) => account?.id == activeId,
              orElse: () => null,
            );

    if (allowed == null) {
      final activeAccounts =
          accounts.where((account) => account.isActive).toList();
      if (activeAccounts.length == 1) {
        allowed = activeAccounts.first;
      }
    }

    if (allowed == null) {
      AuthDebug.log(
        'sanitizeAccountSessions:noAllowedAccount',
        {'activeId': activeId, 'loginEmail': loginEmail},
      );
      return accounts;
    }

    final allowedId = allowed.id;
    var changed = false;
    final sanitized = accounts.map((account) {
      if (account.id == allowedId) {
        if (!account.isActive) changed = true;
        return account.copyWith(isActive: true);
      }
      if (account.isActive ||
          account.hasStoredSession ||
          account.password.isNotEmpty) {
        changed = true;
      }
      return account.copyWith(
        isActive: false,
        sessionId: null,
        password: '',
      );
    }).toList();

    if (changed) {
      AuthDebug.log(
        'sanitizeAccountSessions:strippedOtherAccounts',
        {'allowedUser': allowed.username},
      );
    }
    return sanitized;
  }

  static Future<void> saveAccount(AccountModel account) async {
    final accounts = await getAllAccounts();

    final normalized = account.copyWith(
      username: account.username.trim(),
      url: account.url.trim(),
    );

    final byId = accounts.indexWhere((a) => a.id == normalized.id);
    final byIdentity = accounts.indexWhere(
      (a) => AccountModel.isSameIdentity(a, normalized),
    );

    final AccountModel toSave;
    if (byId >= 0) {
      toSave = normalized;
      accounts[byId] = toSave;
    } else if (byIdentity >= 0) {
      toSave = normalized.copyWith(id: accounts[byIdentity].id);
      accounts[byIdentity] = toSave;
    } else {
      toSave = normalized;
      accounts.add(toSave);
    }

    await _writeAccounts(
      _sortByRecentLogin(_dedupeByIdentity(accounts)),
    );
    AuthDebug.log('saveAccount', {'user': toSave.username, 'id': toSave.id});
  }

  static Future<void> _writeAccounts(List<AccountModel> accounts) async {
    await _box.write(
      _keyAccounts,
      accounts.map((a) => a.toJson()).toList(),
    );
  }

  static List<AccountModel> _dedupeByIdentity(List<AccountModel> accounts) {
    final result = <AccountModel>[];
    for (final account in accounts) {
      final index = result.indexWhere(
        (a) => AccountModel.isSameIdentity(a, account),
      );
      if (index < 0) {
        result.add(account);
        continue;
      }
      final existing = result[index];
      final existingTime =
          existing.lastLogin ?? DateTime.fromMillisecondsSinceEpoch(0);
      final candidateTime =
          account.lastLogin ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (!candidateTime.isBefore(existingTime)) {
        result[index] = account.copyWith(id: existing.id);
      }
    }
    return result;
  }

  static Future<int?> getLoginUserId() async {
    return _box.read<int>('login_user_id');
  }

  static Future<AccountModel?> getPersistedLoginAccount() async {
    if (!await isLoggedIn()) return null;

    final loginUrl = _box.read<String>('login_url');
    final loginDb = _box.read<String>('login_db');
    final loginEmail = _box.read<String>('login_email');
    if (loginUrl == null || loginDb == null || loginEmail == null) {
      AuthDebug.log('getPersistedLoginAccount:missingLoginKeys');
      return null;
    }

    final loginMode =
        _box.read<String>('login_mode') ?? AccountModel.modeUser;

    final accounts = await getAllAccounts();
    AccountModel? account;
    AccountModel? credentialMatch;
    for (final entry in accounts) {
      if (entry.matchesCredentials(
        url: loginUrl,
        database: loginDb,
        username: loginEmail,
      )) {
        credentialMatch ??= entry;
        // Prefer the account whose mode matches so a user login and an employee
        // login sharing the same email resolve to the right one.
        if (entry.loginMode == loginMode) {
          account = entry;
          break;
        }
      }
    }
    account ??= credentialMatch;

    AuthDebug.log(
      'getPersistedLoginAccount',
      {
        'requestedUser': loginEmail,
        'resolvedUser': account?.username,
        'resolvedId': account?.id,
        'mode': loginMode,
      },
    );
    return account;
  }

  static Future<AccountModel?> getActiveAccount() async {
    return getPersistedLoginAccount();
  }

  /// Marks one account as the only signed-in account on this device.
  static Future<void> activateLoggedInAccount(AccountModel active) async {
    final accounts = await getAllAccounts();
    final normalized = active.copyWith(
      username: active.username.trim(),
      url: active.url.trim(),
      isActive: true,
    );

    AuthDebug.log(
      'activateLoggedInAccount:start',
      {
        'targetUser': normalized.username,
        'targetId': normalized.id,
        'existingCount': accounts.length,
      },
    );

    String activeId = normalized.id;
    var found = false;
    final updated = accounts.map((account) {
      if (account.id == normalized.id ||
          AccountModel.isSameIdentity(account, normalized)) {
        found = true;
        activeId = account.id;
        return normalized.copyWith(id: account.id);
      }
      return account.copyWith(
        isActive: false,
        sessionId: null,
        password: '',
      );
    }).toList();

    if (!found) {
      updated.add(normalized);
      activeId = normalized.id;
    }

    final deduped = _sortByRecentLogin(_dedupeByIdentity(updated));
    await _writeAccounts(deduped);
    await _box.write(_keyActiveAccountId, activeId);

    AuthDebug.accounts('activateLoggedInAccount:done', deduped);
  }

  static Future<void> setActiveAccount(String accountId) async {
    final accounts = await getAllAccounts();
    final updated = accounts
        .map(
          (a) => a.id == accountId
              ? a.copyWith(isActive: true)
              : a.copyWith(
                  isActive: false,
                  sessionId: null,
                  password: '',
                ),
        )
        .toList();
    await _writeAccounts(updated);
    await _box.write(_keyActiveAccountId, accountId);
  }

  static Future<void> invalidateOtherAccountSessions(String activeAccountId) async {
    final accounts = await getAllAccounts();
    final updated = accounts
        .map(
          (a) => a.id == activeAccountId
              ? a
              : a.copyWith(
                  isActive: false,
                  sessionId: null,
                  password: '',
                ),
        )
        .toList();
    await _writeAccounts(updated);
  }

  static Future<void> markAllAccountsSignedOut() async {
    final accounts = await getAllAccounts();
    if (accounts.isEmpty) return;

    final updated = accounts.map(toRememberedOnly).toList();
    await _writeAccounts(updated);
    await _box.remove(_keyActiveAccountId);
    AuthDebug.accounts('markAllAccountsSignedOut', updated);
  }

  static Future<void> deleteAccount(String accountId) async {
    final accounts = await getAllAccounts();
    accounts.removeWhere((a) => a.id == accountId);
    await _writeAccounts(accounts);
    final activeId = _box.read<String>(_keyActiveAccountId);
    if (activeId == accountId) {
      await _box.remove(_keyActiveAccountId);
    }
    AuthDebug.log('deleteAccount', {'id': accountId});
  }

  static Future<List<int>?> getSelectedCompanyIds() async {
    final raw = _box.read<List<dynamic>>(_keySelectedCompanyIds);
    if (raw == null) return null;
    return raw.cast<int>();
  }

  static Future<void> saveSelectedCompanyIds(List<int> ids) async {
    await _box.write(_keySelectedCompanyIds, ids);
  }

  static Future<void> clearSelectedCompanyIds() async {
    await _box.remove(_keySelectedCompanyIds);
  }
}
