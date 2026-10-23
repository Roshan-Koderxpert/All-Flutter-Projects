import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:uuid/uuid.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/utils/api_logger.dart';
import '../../../core/utils/auth_debug.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../data/local/auth_storage.dart';
import '../../../data/models/account_model.dart';
import '../../../data/services/employee_auth_service.dart';
import '../../../data/services/location_tracking_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/odoo_auth_service.dart';
import '../../../data/services/odoo_session_parser.dart';
import '../../../data/services/odoo_totp_service.dart';
import '../../approvals/controllers/approvals_controller.dart';
import '../../attendance/controllers/attendance_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/controllers/main_controller.dart';
import '../../leave/controllers/leave_controller.dart';
class AuthController extends GetxController {
  OdooClient? odooClient;

  final isLoading = false.obs;
  final isSwitchingAccount = false.obs;
  final isLoggedIn = false.obs;
  final userName = ''.obs;
  final odooUrl = ''.obs;

  final databases = <String>[].obs;
  final selectedDatabase = ''.obs;

  final companies = <Map<String, dynamic>>[].obs;
  final selectedCompanyIds = <int>[].obs;
  final selectedCompanyNames = ''.obs;

  final savedAccounts = <AccountModel>[].obs;
  final activeAccount = Rxn<AccountModel>();

  /// Per-employee feature rights for an employee-mode session (empty in user
  /// mode). Keys are from [kMobileAccessFeatures].
  final employeeMobileAccess = <String, bool>{}.obs;

  final _uuid = const Uuid();

  bool get isEmployeeMode => activeAccount.value?.isEmployeeMode == true;

  /// Whether the current session may use [feature]. User-mode sessions always
  /// can; employee-mode sessions are limited by their Mobile Access rights.
  bool employeeCanUse(String feature) {
    if (!isEmployeeMode) return true;
    return employeeMobileAccess[feature] ?? false;
  }

  /// The employee id every screen must scope to in employee mode (from the
  /// login response), or null in user mode. Employee-mode sessions run on the
  /// shared app user, so resolving the employee from the *user* would wrongly
  /// land on the shared account's own employee — always use this instead.
  int? get scopedEmployeeId =>
      isEmployeeMode ? activeAccount.value?.employeeId : null;

  @override
  void onInit() {
    super.onInit();
    ever(selectedCompanyIds, (_) => _onCompanyChanged());
    loadSavedAccounts();
  }

  void _onCompanyChanged() {
    if (selectedCompanyIds.isEmpty || isLoading.value) return;
    _updateCompanyNamesDisplay();
  }

  void _updateCompanyNamesDisplay() {
    if (selectedCompanyIds.isEmpty) {
      selectedCompanyNames.value = 'No company selected';
      return;
    }
    final names = companies
        .where((c) => selectedCompanyIds.contains(c['id']))
        .map((c) => c['name'] as String)
        .join(', ');
    selectedCompanyNames.value = names;
  }

  Future<void> toggleCompanySelection(int companyId) async {
    if (selectedCompanyIds.contains(companyId)) {
      if (selectedCompanyIds.length <= 1) {
        Get.snackbar(
          'Company',
          'At least one company must be selected',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      selectedCompanyIds.remove(companyId);
    } else {
      selectedCompanyIds.add(companyId);
    }
    _updateCompanyNamesDisplay();
    await AuthStorage.saveSelectedCompanyIds(selectedCompanyIds);
  }

  Future<void> loadSavedAccounts() async {
    try {
      await AuthStorage.migrateLegacyLoginIfNeeded();
      savedAccounts.value = await AuthStorage.getAllAccounts();
      AuthDebug.accounts('loadSavedAccounts', savedAccounts);
      if (await AuthStorage.isLoggedIn()) {
        activeAccount.value = await AuthStorage.getPersistedLoginAccount();
        AuthDebug.log(
          'loadSavedAccounts:active',
          {
            'user': activeAccount.value?.username,
            'id': activeAccount.value?.id,
          },
        );
      } else {
        activeAccount.value = null;
        AuthDebug.log('loadSavedAccounts:signedOut');
      }
    } catch (e) {
      debugPrint('Error loading saved accounts: $e');
      AuthDebug.log('loadSavedAccounts:error', {'error': e.toString()});
    }
  }

  Future<void> fetchCompanies() async {
    if (odooClient == null) throw Exception('Not logged in');

    final result = await odooClient!.callKw({
      'model': 'res.company',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'fields': ['id', 'name', 'currency_id', 'partner_id'],
        'order': 'name asc',
      },
    });

    companies.assignAll(List<Map<String, dynamic>>.from(result));

    if (companies.isNotEmpty && selectedCompanyIds.isEmpty) {
      final savedIds = await AuthStorage.getSelectedCompanyIds();
      if (savedIds != null && savedIds.isNotEmpty) {
        selectedCompanyIds.value = savedIds
            .where((id) => companies.any((c) => c['id'] == id))
            .toList();
      } else {
        selectedCompanyIds.value = [companies.first['id'] as int];
      }
      _updateCompanyNamesDisplay();
      await AuthStorage.saveSelectedCompanyIds(selectedCompanyIds);
    }
  }

  Future<Map<String, dynamic>?> fetchUserDetails(int userId) async {
    if (odooClient == null) return null;

    try {
      final result = await odooClient!.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', userId],
          ],
          ['name', 'email', 'image_1920', 'image_128'],
        ],
        'kwargs': {},
      });

      if (result is List && result.isNotEmpty) {
        final userData = Map<String, dynamic>.from(result.first as Map);
        if (userData['image_1920'] == false) userData['image_1920'] = null;
        if (userData['image_128'] == false) userData['image_128'] = null;
        return userData;
      }
    } catch (e) {
      debugPrint('Error fetching user details: $e');
    }
    return null;
  }

  /// Returns `true` when session was restored successfully.
  Future<bool> tryAutoLogin({bool navigate = true}) async {
    try {
      AuthDebug.log('tryAutoLogin:start');
      if (!await AuthStorage.isLoggedIn()) {
        isLoggedIn.value = false;
        AuthDebug.log('tryAutoLogin:skippedNotLoggedIn');
        return false;
      }

      final account = await AuthStorage.getPersistedLoginAccount();
      if (account == null) {
        await AuthStorage.clearLogin();
        isLoggedIn.value = false;
        AuthDebug.log('tryAutoLogin:noPersistedAccount');
        return false;
      }

      if (!account.isActive || !account.canSilentSignIn) {
        await AuthStorage.clearLogin();
        isLoggedIn.value = false;
        AuthDebug.log(
          'tryAutoLogin:inactiveOrNoCredentials',
          {'user': account.username},
        );
        return false;
      }

      // Employee-mode accounts re-authenticate through the employee endpoint
      // (they run on the shared user, so there is no personal session to reuse).
      if (account.isEmployeeMode) {
        return await _tryEmployeeAutoLogin(account, navigate: navigate);
      }

      final loginUserId = await AuthStorage.getLoginUserId();
      if (loginUserId != null && account.userId != loginUserId) {
        await AuthStorage.clearLogin();
        isLoggedIn.value = false;
        AuthDebug.log(
          'tryAutoLogin:userIdMismatch',
          {'accountUserId': account.userId, 'loginUserId': loginUserId},
        );
        return false;
      }

      AuthDebug.log(
        'tryAutoLogin:target',
        {'user': account.username, 'id': account.id},
      );

      // 1) Reuse saved Odoo session cookie (works after app kill; required for 2FA users).
      if (account.sessionId != null && account.sessionId!.isNotEmpty) {
        final restored = await _tryRestoreFromSessionId(account);
        if (restored != null) {
          await _applyRestoredAccount(account, restored);
          if (navigate) {
            Get.offAllNamed(AppRoutes.home);
          }
          return true;
        }
        debugPrint('Auto-login: saved session expired, trying password auth');
      }

      // 2) Fall back to password auth (non-2FA accounts).
      final attempt = await OdooAuthService.attemptAuthenticate(
        baseUrl: account.url,
        db: account.database,
        login: account.username,
        password: account.password,
      );

      if (attempt.requiresTotp) {
        debugPrint('Auto-login: account requires 2FA — session not restored');
        isLoggedIn.value = false;
        return false;
      }

      if (attempt.session != null && attempt.session!.userId > 0) {
        await _applyRestoredAccount(account, attempt.session!);
        if (navigate) {
          Get.offAllNamed(AppRoutes.home);
        }
        return true;
      }

      isLoggedIn.value = false;
      return false;
    } on OdooException catch (e) {
      debugPrint('Auto-login auth error: $e');
      if (_isInvalidCredentialsError(e)) {
        await AuthStorage.clearLogin();
      }
      isLoggedIn.value = false;
      return false;
    } catch (e) {
      debugPrint('Auto-login error: $e');
      isLoggedIn.value = false;
      return false;
    }
  }

  Future<OdooSession?> _tryRestoreFromSessionId(AccountModel account) async {
    final sessionId = account.sessionId;
    if (sessionId == null || sessionId.isEmpty) return null;

    try {
      final sessionInfo = await OdooTotpService.getSessionInfo(
        account.url,
        sessionId,
      );
      if (!OdooSessionParser.isAuthenticated(sessionInfo)) {
        return null;
      }
      return OdooSessionParser.fromSessionInfo(
        sessionInfo,
        fallbackSessionId: sessionId,
      );
    } catch (e) {
      debugPrint('Session restore failed: $e');
      return null;
    }
  }

  Future<void> _applyRestoredAccount(
    AccountModel account,
    OdooSession session,
  ) async {
    odooClient = OdooClient(account.url, session);
    odooUrl.value = account.url;
    selectedDatabase.value = account.database;

    final userDetails = await fetchUserDetails(session.userId);
    final updatedAccount = account.copyWith(
      userId: session.userId,
      sessionId: session.id,
      isActive: true,
      name: userDetails?['name'] as String?,
      email: userDetails?['email'] as String?,
      image1920: OdooImage.sanitize(userDetails?['image_1920']),
      lastLogin: DateTime.now(),
    );

    isLoggedIn.value = true;
    userName.value = account.username;
    activeAccount.value = updatedAccount;

    await AuthStorage.activateLoggedInAccount(updatedAccount);
    await AuthStorage.saveLogin(
      url: updatedAccount.url,
      db: updatedAccount.database,
      userId: updatedAccount.userId,
      sessionId: session.id,
      email: updatedAccount.username,
      password: updatedAccount.password,
    );
    try {
      await fetchCompanies();
    } catch (e, st) {
      AuthDebug.log('applyRestoredAccount:fetchCompanies:ERROR', {'error': e.toString()});
      debugPrint('fetchCompanies failed (non-fatal): $e\n$st');
    }
    await loadSavedAccounts();
    await _registerPushToken();

  }

  bool _isInvalidCredentialsError(OdooException error) {
    final message = error.toString().toLowerCase();
    return message.contains('authentication failed') ||
        message.contains('access denied') ||
        message.contains('invalid credentials');
  }

  // NOTE: "Restrict Mobile App Access" no longer blocks User sign-in.
  // The switch only decides whether the Employee tab is offered on the
  // login screen; any internal user may sign in as a User either way.

  Future<void> fetchDatabases(String url) async {
    isLoading.value = true;
    databases.clear();
    selectedDatabase.value = '';

    try {
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        throw Exception('Invalid URL format');
      }

      odooClient = OdooClient(url);
      odooUrl.value = url;

      final dbList =
          await odooClient!.callRPC('/web/database/list', 'call', {});

      if (dbList is List && dbList.isNotEmpty) {
        databases.value =
            dbList.map((e) => e.toString()).toSet().toList();
        selectedDatabase.value = databases.first;
      } else {
        throw Exception('No databases found on this server');
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Returns `true` when navigation to the 2FA screen was triggered.
  Future<bool> login(String url, String username, String password) async {
    var cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    if (selectedDatabase.value.isEmpty) {
      throw Exception('Please select a database');
    }

    AuthDebug.log('authController:login:attempt', {
      'url': cleanUrl,
      'db': selectedDatabase.value,
      'username': username,
    });

    try {
      final attempt = await OdooAuthService.attemptAuthenticate(
        baseUrl: cleanUrl,
        db: selectedDatabase.value,
        login: username,
        password: password,
      );

      AuthDebug.log('authController:login:result', {
        'requiresTotp': attempt.requiresTotp,
        'hasSession': attempt.session != null,
        'sessionUserId': attempt.session?.userId,
      });

      if (attempt.requiresTotp) {
        Get.toNamed(
          AppRoutes.twoFactor,
          arguments: {
            'baseUrl': cleanUrl,
            'db': selectedDatabase.value,
            'login': username,
            'password': password,
            'sessionId': attempt.partialSessionId,
            'flow': 'login',
          },
        );
        return true;
      }

      await _finalizeLogin(
        cleanUrl: cleanUrl,
        username: username,
        password: password,
        session: attempt.session!,
      );
      return false;
    } catch (e, st) {
      AuthDebug.log('authController:login:ERROR', {
        'type': e.runtimeType.toString(),
        'error': e.toString(),
      });
      debugPrint('authController.login ERROR: $e\n$st');
      rethrow;
    }
  }



  Future<void> completeLoginAfterTotp({
    required String baseUrl,
    required String db,
    required String username,
    required String password,
    required String sessionId,
    Map<String, dynamic>? sessionInfo,
  }) async {
    final info = sessionInfo ??
        await OdooTotpService.getSessionInfo(baseUrl, sessionId);

    if (!OdooSessionParser.isAuthenticated(info)) {
      throw Exception('Session not fully authenticated after 2FA');
    }

    final session = OdooSessionParser.fromSessionInfo(
      info,
      fallbackSessionId: sessionId,
    );

    await _finalizeLogin(
      cleanUrl: baseUrl,
      username: username,
      password: password,
      session: session,
      database: db,
    );
  }

  /// Add another account from Profile (same server/db as active account).
  /// Skips if the account is already saved (switches instead).
  /// Returns `true` when navigation to the 2FA screen was triggered.
  Future<bool> addAccount({
    required String url,
    required String database,
    required String username,
    required String password,
  }) async {
    var cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) {
      throw Exception('Please enter username');
    }
    if (password.isEmpty) {
      throw Exception('Please enter password');
    }

    await loadSavedAccounts();
    final existing = savedAccounts.firstWhereOrNull(
      (a) => a.matchesCredentials(
        url: cleanUrl,
        database: database,
        username: trimmedUsername,
      ),
    );

    if (existing != null) {
      if (existing.id == activeAccount.value?.id) {
        throw Exception('This account is already active');
      }
      await switchAccount(existing);
      return false;
    }

    final attempt = await OdooAuthService.attemptAuthenticate(
      baseUrl: cleanUrl,
      db: database,
      login: trimmedUsername,
      password: password,
    );

    if (attempt.requiresTotp) {
      Get.toNamed(
        AppRoutes.twoFactor,
        arguments: {
          'baseUrl': cleanUrl,
          'db': database,
          'login': trimmedUsername,
          'password': password,
          'sessionId': attempt.partialSessionId ?? '',
          'flow': 'addAccount',
          'awaitCredentials': false,
        },
      );
      return true;
    }

    if (attempt.session == null || attempt.session!.userId <= 0) {
      throw OdooException('Authentication failed');
    }

    await _finalizeAddAccount(
      cleanUrl: cleanUrl,
      database: database,
      username: trimmedUsername,
      password: password,
      session: attempt.session!,
    );
    return false;
  }

  Future<void> completeAddAccount({
    required String baseUrl,
    required String db,
    required String username,
    required String password,
    required OdooSession session,
  }) async {
    await _finalizeAddAccount(
      cleanUrl: baseUrl,
      database: db,
      username: username,
      password: password,
      session: session,
    );
  }

  Future<void> completeAddAccountAfterTotp({
    required String baseUrl,
    required String db,
    required String username,
    required String password,
    required String sessionId,
    Map<String, dynamic>? sessionInfo,
  }) async {
    final info = sessionInfo ??
        await OdooTotpService.getSessionInfo(baseUrl, sessionId);

    if (!OdooSessionParser.isAuthenticated(info)) {
      throw Exception('Session not fully authenticated after 2FA');
    }

    final session = OdooSessionParser.fromSessionInfo(
      info,
      fallbackSessionId: sessionId,
    );

    await _finalizeAddAccount(
      cleanUrl: baseUrl,
      database: db,
      username: username,
      password: password,
      session: session,
    );
  }

  Future<void> _finalizeAddAccount({
    required String cleanUrl,
    required String database,
    required String username,
    required String password,
    required OdooSession session,
  }) async {
    odooClient = OdooClient(cleanUrl, session);

    final userDetails = await fetchUserDetails(session.userId);

    final existingAccounts = await AuthStorage.getAllAccounts();
    final existing = existingAccounts.firstWhereOrNull(
      (a) => a.matchesCredentials(
        url: cleanUrl,
        database: database,
        username: username,
      ),
    );

    final account = AccountModel(
      id: existing?.id ?? _uuid.v4(),
      url: cleanUrl,
      database: database,
      username: username,
      password: password,
      userId: session.userId,
      sessionId: session.id,
      isActive: true,
      name: userDetails?['name'] as String?,
      email: userDetails?['email'] as String?,
      image1920: OdooImage.sanitize(userDetails?['image_1920']),
      lastLogin: DateTime.now(),
    );

    await _activateAccountSession(account, session);
  }

  Future<void> _activateAccountSession(
    AccountModel account,
    OdooSession session,
  ) async {
    odooClient = OdooClient(account.url, session);
    odooUrl.value = account.url;
    selectedDatabase.value = account.database;
    userName.value = account.username;
    activeAccount.value = account;
    isLoggedIn.value = true;

    await AuthStorage.activateLoggedInAccount(account);
    await AuthStorage.saveLogin(
      url: account.url,
      db: account.database,
      userId: account.userId,
      sessionId: session.id,
      email: account.username,
      password: account.password,
    );
    await AuthStorage.invalidateOtherAccountSessions(account.id);
    await loadSavedAccounts();
    try {
      await fetchCompanies();
    } catch (e, st) {
      AuthDebug.log('applyRestoredAccount:fetchCompanies:ERROR', {'error': e.toString()});
      debugPrint('fetchCompanies failed (non-fatal): $e\n$st');
    }
    await _registerPushToken();
    await _hardRefreshAppAfterAccountSwitch().timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        ApiLogger.error('addAccount: hard refresh timed out');
      },
    );
  }

  Future<void> _finalizeLogin({
    required String cleanUrl,
    required String username,
    required String password,
    required OdooSession session,
    String? database,
  }) async {
    final db = database ?? selectedDatabase.value;
    odooClient = OdooClient(cleanUrl, session);
    odooUrl.value = cleanUrl;
    selectedDatabase.value = db;

    final userDetails = await fetchUserDetails(session.userId);

    final existingAccounts = await AuthStorage.getAllAccounts();
    final existing = existingAccounts.firstWhereOrNull(
      (a) => a.matchesCredentials(
        url: cleanUrl,
        database: db,
        username: username,
      ),
    );

    final newAccount = AccountModel(
      id: existing?.id ?? _uuid.v4(),
      url: cleanUrl,
      database: db,
      username: username,
      password: password,
      userId: session.userId,
      sessionId: session.id,
      isActive: true,
      name: userDetails?['name'] as String?,
      email: userDetails?['email'] as String?,
      image1920: OdooImage.sanitize(userDetails?['image_1920']),
      lastLogin: DateTime.now(),
    );

    await AuthStorage.activateLoggedInAccount(newAccount);
    await AuthStorage.saveLogin(
      url: cleanUrl,
      db: db,
      userId: session.userId,
      sessionId: session.id,
      email: username,
      password: password,
    );
    await AuthStorage.invalidateOtherAccountSessions(newAccount.id);

    isLoggedIn.value = true;
    userName.value = username;
    activeAccount.value = newAccount;

    try {
      await fetchCompanies();
    } catch (e, st) {
      AuthDebug.log('finalizeLogin:fetchCompanies:ERROR', {
        'error': e.toString(),
      });
      debugPrint('fetchCompanies failed (non-fatal): $e\n$st');
    }

    await loadSavedAccounts();
    await _verifyActiveSession(newAccount);
    await _registerPushToken();
    AuthDebug.accounts('finalizeLogin:storage', savedAccounts);

    await _resetModuleCaches();
    Get.offAllNamed(AppRoutes.home);
    await _refreshModuleDataAfterAuthChange();
  }

  // ---- Employee (self-service) login -------------------------------------

  /// Signs in with the employee's own credentials. The returned session runs on
  /// the shared predefined user; the app is scoped to the returned employee id
  /// and limited to that employee's Mobile Access rights.
  Future<void> employeeLogin({
    required String url,
    required String database,
    required String email,
    required String password,
    bool navigate = true,
  }) async {
    var cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    final trimmedEmail = email.trim();

    final result = await EmployeeAuthService.login(
      baseUrl: cleanUrl,
      db: database,
      email: trimmedEmail,
      password: password,
    );

    await _finalizeEmployeeLogin(
      cleanUrl: cleanUrl,
      database: database,
      email: trimmedEmail,
      password: password,
      result: result,
      navigate: navigate,
    );
  }

  Future<void> _finalizeEmployeeLogin({
    required String cleanUrl,
    required String database,
    required String email,
    required String password,
    required EmployeeLoginResult result,
    bool navigate = true,
  }) async {
    final session = result.session;
    odooClient = OdooClient(cleanUrl, session);
    odooUrl.value = cleanUrl;
    selectedDatabase.value = database;

    final existingAccounts = await AuthStorage.getAllAccounts();
    final existing = existingAccounts.firstWhereOrNull(
      (a) =>
          a.loginMode == AccountModel.modeEmployee &&
          a.matchesCredentials(
            url: cleanUrl,
            database: database,
            username: email,
          ),
    );

    final account = AccountModel(
      id: existing?.id ?? _uuid.v4(),
      url: cleanUrl,
      database: database,
      username: email,
      password: password,
      userId: session.userId,
      sessionId: session.id,
      isActive: true,
      name: result.employeeName,
      email: email,
      lastLogin: DateTime.now(),
      loginMode: AccountModel.modeEmployee,
      employeeId: result.employeeId,
    );

    employeeMobileAccess.assignAll(result.mobileAccess);

    await AuthStorage.activateLoggedInAccount(account);
    await AuthStorage.saveLogin(
      url: cleanUrl,
      db: database,
      userId: session.userId,
      sessionId: session.id,
      email: email,
      password: password,
      loginMode: AccountModel.modeEmployee,
    );
    await AuthStorage.invalidateOtherAccountSessions(account.id);

    isLoggedIn.value = true;
    userName.value = result.employeeName ?? email;
    activeAccount.value = account;

    try {
      await fetchCompanies();
    } catch (e) {
      debugPrint('fetchCompanies (employee) failed: $e');
    }
    await loadSavedAccounts();
    // No push-token registration in employee mode: it would register every
    // employee's device against the one shared user.

    if (navigate) {
      await _resetModuleCaches();
      Get.offAllNamed(AppRoutes.home);
      await _refreshModuleDataAfterAuthChange();
    }
  }

  Future<bool> _tryEmployeeAutoLogin(
    AccountModel account, {
    required bool navigate,
  }) async {
    if (account.password.isEmpty) {
      isLoggedIn.value = false;
      return false;
    }
    try {
      await employeeLogin(
        url: account.url,
        database: account.database,
        email: account.username,
        password: account.password,
        navigate: navigate,
      );
      return isLoggedIn.value;
    } catch (e) {
      debugPrint('Employee auto-login failed: $e');
      isLoggedIn.value = false;
      return false;
    }
  }

  /// Re-reads the current employee's Mobile Access rights (employee mode only)
  /// so feature gating reflects admin changes without an app restart. Calls the
  /// employee endpoint again just to read fresh `access_rights`; the current
  /// session keeps being used, so there is no re-navigation.
  Future<void> refreshEmployeeAccess() async {
    final account = activeAccount.value;
    if (account == null || !account.isEmployeeMode) return;
    if (account.password.isEmpty) return;
    try {
      final result = await EmployeeAuthService.login(
        baseUrl: account.url,
        db: account.database,
        email: account.username,
        password: account.password,
      );
      employeeMobileAccess.assignAll(result.mobileAccess);
    } catch (e) {
      debugPrint('refreshEmployeeAccess failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      await LocationTrackingService.instance.stop();
      await _unregisterPushToken();
      await _clearCurrentSession();
      await AuthStorage.clearLogin();

      if (activeAccount.value != null) {
        final updated = AuthStorage.toRememberedOnly(activeAccount.value!);
        await AuthStorage.saveAccount(updated);
      }

      await AuthStorage.clearSelectedCompanyIds();

      isLoggedIn.value = false;
      userName.value = '';
      databases.clear();
      selectedDatabase.value = '';
      odooClient = null;
      activeAccount.value = null;

      await _resetModuleCaches();
      await loadSavedAccounts();

      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      debugPrint('Logout error: $e');
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<void> logoutAll() async {
    try {
      await LocationTrackingService.instance.stop();
      await _unregisterPushToken();
      AuthDebug.log('logoutAll:start', {
        'activeUser': activeAccount.value?.username,
        'savedCount': savedAccounts.length,
      });

      final accounts = await AuthStorage.getAllAccounts();
      for (final account in accounts) {
        if (account.hasStoredSession) {
          await _destroyRemoteSession(account);
        }
      }

      await _clearCurrentSession();
      await AuthStorage.markAllAccountsSignedOut();
      await AuthStorage.clearLogin();
      await AuthStorage.clearSelectedCompanyIds();

      isLoggedIn.value = false;
      userName.value = '';
      databases.clear();
      selectedDatabase.value = '';
      odooClient = null;
      activeAccount.value = null;

      await _resetModuleCaches();
      await loadSavedAccounts();

      AuthDebug.accounts('logoutAll:done', savedAccounts);
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      debugPrint('Logout all error: $e');
      AuthDebug.log('logoutAll:error', {'error': e.toString()});
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<void> _verifyActiveSession(AccountModel account) async {
    final session = odooClient?.sessionId;
    if (session == null) {
      AuthDebug.log('verifySession:noClient');
      return;
    }
    AuthDebug.log(
      'verifySession',
      {
        'expectedUser': account.username,
        'expectedUserId': account.userId,
        'sessionUserId': session.userId,
        'sessionLogin': session.userLogin,
        'sessionName': session.userName,
      },
    );
    if (session.userId != account.userId) {
      AuthDebug.log(
        'verifySession:MISMATCH',
        {
          'account': account.username,
          'sessionUid': session.userId,
        },
      );
    }
  }

  Future<void> _registerPushToken() async {
    if (odooClient == null) return;
    try {
      final fcmToken = await Get.find<NotificationService>().getToken();
      if (fcmToken == null) return;
      await odooClient!.callKw({
        'model': 'res.users.device.token',
        'method': 'register_token',
        'args': [fcmToken, Platform.isIOS ? 'ios' : 'android'],
        'kwargs': {},
      });
    } catch (e) {
      debugPrint('Push token registration failed: $e');
    }
  }

  Future<void> _unregisterPushToken() async {
    if (odooClient == null) return;
    try {
      final fcmToken = await Get.find<NotificationService>().getToken();
      if (fcmToken == null) return;
      await odooClient!.callKw({
        'model': 'res.users.device.token',
        'method': 'unregister_token',
        'args': [fcmToken],
        'kwargs': {},
      });
    } catch (e) {
      debugPrint('Push token unregistration failed: $e');
    }
  }

  Future<void> _destroyRemoteSession(AccountModel account) async {
    if (!account.hasStoredSession) return;
    try {
      final sessionId = account.sessionId!;
      final info = await OdooTotpService.getSessionInfo(account.url, sessionId);
      if (!OdooSessionParser.isAuthenticated(info)) return;
      final session = OdooSessionParser.fromSessionInfo(
        info,
        fallbackSessionId: sessionId,
      );
      final client = OdooClient(account.url, session);
      await client.destroySession();
      AuthDebug.log(
        'destroyRemoteSession:ok',
        {'user': account.username},
      );
    } catch (e) {
      AuthDebug.log(
        'destroyRemoteSession:failed',
        {'user': account.username, 'error': e.toString()},
      );
    }
  }

  /// Opens login screen to sign in a remembered account (no silent switch).
  Future<void> signInSavedAccount(AccountModel account) async {
    AuthDebug.log(
      'signInSavedAccount',
      {'user': account.username, 'id': account.id},
    );
    await _clearCurrentSession();
    await AuthStorage.clearLogin();

    if (activeAccount.value != null) {
      final updated = AuthStorage.toRememberedOnly(activeAccount.value!);
      await AuthStorage.saveAccount(updated);
    }

    isLoggedIn.value = false;
    userName.value = '';
    odooClient = null;
    activeAccount.value = null;
    selectedCompanyIds.clear();
    selectedCompanyNames.value = '';
    companies.clear();

    await AuthStorage.clearSelectedCompanyIds();
    await loadSavedAccounts();

    Get.offAllNamed(
      AppRoutes.login,
      arguments: {'prefillAccountId': account.id},
    );
  }

  Future<void> _clearCurrentSession() async {
    if (odooClient != null) {
      try {
        await odooClient!.destroySession();
      } catch (e) {
        debugPrint('Session destroy warning: $e');
      }
    }
    selectedCompanyIds.clear();
    selectedCompanyNames.value = '';
    companies.clear();
  }

  Future<bool> switchAccount(AccountModel account) async {
    if (!account.canSilentSignIn) {
      AuthDebug.log(
        'switchAccount:blocked',
        {'user': account.username, 'reason': 'noStoredCredentials'},
      );
      throw Exception(
        'Please sign in again from the login screen for ${account.username}',
      );
    }

    isLoading.value = true;
    isSwitchingAccount.value = true;
    try {
      AuthDebug.log(
        'switchAccount:start',
        {
          'user': account.username,
          'hasSession': account.hasStoredSession,
          'hasPassword': account.password.isNotEmpty,
        },
      );

      final restored = await _tryRestoreFromSessionId(account);
      if (restored != null) {
        await _applyRestoredAccount(account, restored);
        await _hardRefreshAppAfterAccountSwitch();
        ApiLogger.info(
          'switchAccount completed via session restore username=${account.username}',
        );
        return false;
      }

      ApiLogger.info(
        'switchAccount session restore failed, trying password auth',
      );

      final attempt = await OdooAuthService.attemptAuthenticate(
        baseUrl: account.url,
        db: account.database,
        login: account.username,
        password: account.password,
      );

      if (attempt.requiresTotp) {
        isLoading.value = false;
        isSwitchingAccount.value = false;
        Get.toNamed(
          AppRoutes.twoFactor,
          arguments: {
            'baseUrl': account.url,
            'db': account.database,
            'login': account.username,
            'password': account.password,
            'sessionId': attempt.partialSessionId ?? '',
            'flow': 'switchAccount',
            'accountId': account.id,
            'awaitCredentials': false,
          },
        );
        return true;
      }

      if (attempt.session == null || attempt.session!.userId <= 0) {
        throw OdooException('Authentication failed');
      }

      await _applyRestoredAccount(account, attempt.session!);
      await _hardRefreshAppAfterAccountSwitch();
      ApiLogger.info('switchAccount completed username=${account.username}');
      return false;
    } catch (e, st) {
      ApiLogger.error('switchAccount failed username=${account.username}', e, st);
      rethrow;
    } finally {
      isLoading.value = false;
      isSwitchingAccount.value = false;
    }
  }

  Future<void> completeSwitchAccountAfterTotp({
    required String baseUrl,
    required String db,
    required String username,
    required String password,
    required String sessionId,
    required String accountId,
    Map<String, dynamic>? sessionInfo,
  }) async {
    final info = sessionInfo ??
        await OdooTotpService.getSessionInfo(baseUrl, sessionId);

    if (!OdooSessionParser.isAuthenticated(info)) {
      throw Exception('Session not fully authenticated after 2FA');
    }

    final session = OdooSessionParser.fromSessionInfo(
      info,
      fallbackSessionId: sessionId,
    );

    await loadSavedAccounts();
    final account = savedAccounts.firstWhereOrNull((a) => a.id == accountId);
    if (account == null) {
      throw Exception('Account not found');
    }

    isSwitchingAccount.value = true;
    try {
      await _applyRestoredAccount(account, session);
      await _hardRefreshAppAfterAccountSwitch();
    } finally {
      isSwitchingAccount.value = false;
    }
  }

  Future<Map<String, dynamic>?> fetchUserDetailsWithClient(
    OdooClient client,
    int userId,
  ) async {
    try {
      final result = await client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', userId],
          ],
          ['name', 'email', 'image_1920', 'image_128'],
        ],
        'kwargs': {},
      });

      if (result is List && result.isNotEmpty) {
        final userData = Map<String, dynamic>.from(result.first as Map);
        if (userData['image_1920'] == false) userData['image_1920'] = null;
        if (userData['image_128'] == false) userData['image_128'] = null;
        return userData;
      }
    } catch (e) {
      debugPrint('Error fetching user details with client: $e');
    }
    return null;
  }

  Future<void> removeAccount(String accountId) async {
    final activeId = activeAccount.value?.id;
    await AuthStorage.deleteAccount(accountId);
    await loadSavedAccounts();
    if (activeId == accountId && isLoggedIn.value) {
      if (savedAccounts.isNotEmpty) {
        final next = savedAccounts.firstWhereOrNull(
          (account) => account.canSilentSignIn,
        );
        if (next != null) {
          await switchAccount(next);
          return;
        }
      }
      await _clearCurrentSession();
      await AuthStorage.clearLogin();
      isLoggedIn.value = false;
      activeAccount.value = null;
      userName.value = '';
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<void> _hardRefreshAppAfterAccountSwitch() async {
    ApiLogger.info('switchAccount: hard refresh app state');
    await _resetModuleCaches();
    Get.offAllNamed(AppRoutes.home);
    await _refreshModuleDataAfterAuthChange();
  }

  Future<void> _resetModuleCaches() async {
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      home.employeeId.value = null;
      home.employeeName.value = '';
      home.jobTitle.value = '';
      home.departmentName.value = '';
      home.avatarBase64.value = null;
      home.leaveBalances.clear();
      home.attendanceStatus.value = 'not_checked';
      home.checkInTime.value = null;
      home.checkOutTime.value = null;
      home.workedHoursToday.value = 0;
      home.pendingApprovals.value = 0;
      home.pendingTasks.value = 0;
      home.upcomingHolidays.clear();
    }
    if (Get.isRegistered<LeaveController>()) {
      final leave = Get.find<LeaveController>();
      leave.activeEmployeeId.value = null;
      leave.balances.clear();
      leave.allRequests.clear();
      leave.filteredRequests.clear();
      leave.leaveTypes.clear();
    }
    if (Get.isRegistered<AttendanceController>()) {
      final attendance = Get.find<AttendanceController>();
      attendance.records.clear();
    }
    if (Get.isRegistered<ApprovalsController>()) {
      final approvals = Get.find<ApprovalsController>();
      approvals.pendingLeaves.clear();
      approvals.allocations.clear();
    }
  }

  Future<void> _refreshModuleDataAfterAuthChange() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final futures = <Future<void>>[];
    if (Get.isRegistered<MainController>()) {
      futures.add(Get.find<MainController>().refreshApprovalsAccess());
    }
    if (Get.isRegistered<HomeController>()) {
      futures.add(Get.find<HomeController>().loadDashboard());
    }
    if (Get.isRegistered<AttendanceController>()) {
      futures.add(Get.find<AttendanceController>().loadHistory());
    }
    if (Get.isRegistered<LeaveController>()) {
      futures.add(Get.find<LeaveController>().loadLeaves());
    }
    if (Get.isRegistered<ApprovalsController>()) {
      futures.add(Get.find<ApprovalsController>().loadAll());
    }
    if (futures.isEmpty) return;
    try {
      await Future.wait(futures).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      ApiLogger.error('auth change: post-navigation data refresh timed out');
    }
  }
}
