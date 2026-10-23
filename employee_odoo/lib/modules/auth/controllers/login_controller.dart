import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/account_model.dart';
import '../../../data/repositories/mobile_access_repository.dart';
import '../../../data/services/employee_auth_service.dart';
import '../../../core/utils/auth_debug.dart';
import 'auth_controller.dart';

class LoginController extends GetxController {
  final AuthController authController = Get.find<AuthController>();

  final urlController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  final selectedProtocol = 'https://'.obs;
  final urlError = ''.obs;
  final usernameError = ''.obs;
  final passwordError = ''.obs;
  final obscurePassword = true.obs;
  final isFetchingDb = false.obs;
  final showLoginForm = false.obs;
  final errorMessage = ''.obs;

  final showAccountList = false.obs;
  final switchingAccountId = ''.obs;

  /// State for the "Forgot password?" sheet.
  final isRequestingReset = false.obs;
  final resetRequestMessage = ''.obs;
  final resetRequestError = ''.obs;

  /// Which sign-in mode the login screen is showing: User or Employee.
  final loginMode = AccountModel.modeUser.obs;
  final _box = GetStorage();
  static const _modeKey = 'last_login_mode';

  /// Whether the Employee tab is offered, driven by the backend's
  /// "Restrict Mobile App Access" setting for the selected database.
  /// Defaults to true (today's dual-mode behavior) and only flips off when
  /// the server explicitly reports the restriction is disabled.
  final employeeLoginEnabled = true.obs;
  Worker? _dbWatcher;
  int _availabilityRequestSeq = 0;

  bool get isEmployeeMode => loginMode.value == AccountModel.modeEmployee;

  static const Color primaryColor = Color(0xFF6B3E60);

  void setLoginMode(String mode) {
    if (loginMode.value == mode) return;
    loginMode.value = mode;
    _box.write(_modeKey, mode);
    clearError();
    usernameError.value = '';
    passwordError.value = '';
  }

  void clearError() => errorMessage.value = '';

  Future<String> fetchDatabases() async {
    final urlInput = urlController.text.trim();

    if (urlInput.isEmpty) {
      urlError.value = 'Please enter server URL';
      return '';
    }

    isFetchingDb.value = true;
    urlError.value = '';
    errorMessage.value = '';

    try {
      var cleanUrl = urlInput;
      var protocol = selectedProtocol.value;

      if (cleanUrl.startsWith('https://')) {
        protocol = 'https://';
        cleanUrl = cleanUrl.substring(8);
      } else if (cleanUrl.startsWith('http://')) {
        protocol = 'http://';
        cleanUrl = cleanUrl.substring(7);
      }

      cleanUrl = cleanUrl.split('/').first;

      final hostPattern = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$');
      if (!hostPattern.hasMatch(cleanUrl) || cleanUrl.contains('http')) {
        urlError.value = 'Server address looks invalid — please retype it';
        authController.databases.clear();
        authController.selectedDatabase.value = '';
        isFetchingDb.value = false;
        return '';
      }

      selectedProtocol.value = protocol;
      urlController.text = cleanUrl;

      final fullUrl = protocol + cleanUrl;

      authController.databases.clear();
      authController.selectedDatabase.value = '';

      await authController.fetchDatabases(fullUrl);

      authController.databases.value =
          authController.databases.toSet().toList();

      if (authController.databases.isEmpty) {
        urlError.value =
            'No databases found at $cleanUrl. Check the address and try again.';
      }
      return cleanUrl;
    } catch (e) {
      // Surface the real reason (unreachable host, timeout, TLS) rather than
      // always blaming the URL format — a silent/misleading failure here is
      // what made the screen look unresponsive.
      urlError.value =
          'Could not reach $urlInput. Check the address and your connection, '
          'then try again.';
      authController.databases.clear();
      authController.selectedDatabase.value = '';
      return '';
    } finally {
      isFetchingDb.value = false;
    }
  }

  Future<void> handleLogin() async {
    if (isEmployeeMode) {
      await handleEmployeeLogin();
      return;
    }

    usernameError.value = '';
    passwordError.value = '';
    clearError();

    var hasError = false;

    if (usernameController.text.trim().isEmpty) {
      usernameError.value = 'Username is required';
      hasError = true;
    }

    if (passwordController.text.trim().isEmpty) {
      passwordError.value = 'Password is required';
      hasError = true;
    }

    if (hasError) return;

    try {
      final fullUrl = selectedProtocol.value + urlController.text.trim();
      authController.isLoading.value = true;

      AuthDebug.log(
        'loginScreen:submit',
        {
          'user': usernameController.text.trim(),
          'db': authController.selectedDatabase.value,
          'url': fullUrl,
        },
      );

      final navigatedToTwoFactor = await authController.login(
        fullUrl,
        usernameController.text.trim(),
        passwordController.text.trim(),
      );

      if (!navigatedToTwoFactor && !authController.isLoggedIn.value) {
        errorMessage.value = 'Invalid username or password';
      }
    } on MobileAccessDeniedException catch (e) {
      errorMessage.value = e.message;
    } catch (e, st) {
      AuthDebug.log(
        'loginScreen:submit:ERROR',
        {
          'type': e.runtimeType.toString(),
          'error': e.toString(),
        },
      );
      debugPrint('LOGIN ERROR TYPE: ${e.runtimeType}');
      debugPrint('LOGIN ERROR: $e');
      debugPrint('LOGIN STACK: $st');
      errorMessage.value = 'Invalid credentials or server error';
    } finally {
      authController.isLoading.value = false;
    }
  }

  Future<void> handleEmployeeLogin() async {
    usernameError.value = '';
    passwordError.value = '';
    clearError();

    final email = usernameController.text.trim();
    var hasError = false;
    if (email.isEmpty) {
      usernameError.value = 'Login email is required';
      hasError = true;
    }
    if (passwordController.text.isEmpty) {
      passwordError.value = 'Password is required';
      hasError = true;
    }
    if (authController.selectedDatabase.value.isEmpty) {
      errorMessage.value = 'Please choose the server and database first';
      hasError = true;
    }
    if (hasError) return;

    try {
      final fullUrl = selectedProtocol.value + urlController.text.trim();
      authController.isLoading.value = true;
      await authController.employeeLogin(
        url: fullUrl,
        database: authController.selectedDatabase.value,
        email: email,
        password: passwordController.text,
      );
    } on EmployeeAuthException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      debugPrint('EMPLOYEE LOGIN ERROR: $e');
      errorMessage.value = 'Could not sign in. Please try again.';
    } finally {
      authController.isLoading.value = false;
    }
  }

  String get baseUrl => selectedProtocol.value + urlController.text.trim();

  /// Best-guess starting email for the forgot-password sheet: whatever the
  /// user already typed in the credentials field, if it looks like an email.
  String get forgotPasswordInitialEmail {
    final typed = usernameController.text.trim();
    return typed.contains('@') ? typed : '';
  }

  void clearResetRequestState() {
    isRequestingReset.value = false;
    resetRequestMessage.value = '';
    resetRequestError.value = '';
  }

  /// User mode: hands off to Odoo's own password-reset page in the device
  /// browser — the app never handles a full Odoo user's password directly.
  Future<void> requestUserPasswordReset(String email) async {
    resetRequestError.value = '';
    resetRequestMessage.value = '';

    if (baseUrl.isEmpty || urlController.text.trim().isEmpty) {
      resetRequestError.value = 'Please choose a server first.';
      return;
    }

    isRequestingReset.value = true;
    try {
      final uri = Uri.parse('$baseUrl/web/reset_password').replace(
        queryParameters: email.isNotEmpty ? {'login': email} : null,
      );
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        resetRequestError.value = 'Could not open the reset page.';
        return;
      }
      resetRequestMessage.value =
          'We opened your browser to the password reset page. '
          'Follow the link emailed to you to finish.';
    } catch (e) {
      resetRequestError.value = 'Could not open the reset page.';
    } finally {
      isRequestingReset.value = false;
    }
  }

  /// Employee mode: requests a reset email through the module's self-service
  /// endpoint. The completion link opens in the device browser once emailed.
  Future<void> requestEmployeePasswordReset(String email) async {
    resetRequestError.value = '';
    resetRequestMessage.value = '';

    if (baseUrl.isEmpty || urlController.text.trim().isEmpty) {
      resetRequestError.value = 'Please choose a server first.';
      return;
    }
    if (email.trim().isEmpty) {
      resetRequestError.value = 'Enter your login email.';
      return;
    }

    isRequestingReset.value = true;
    try {
      final message = await EmployeeAuthService.requestPasswordReset(
        baseUrl: baseUrl,
        email: email.trim(),
        db: authController.selectedDatabase.value,
      );
      resetRequestMessage.value = message;
    } on EmployeeAuthException catch (e) {
      resetRequestError.value = e.message;
    } catch (e) {
      resetRequestError.value = 'Could not request a reset link. Please try again.';
    } finally {
      isRequestingReset.value = false;
    }
  }

  void goBackToServerConfig() {
    if (showLoginForm.value) {
      showLoginForm.value = false;
      usernameController.clear();
      passwordController.clear();
      usernameError.value = '';
      passwordError.value = '';
      clearError();
    } else if (!showAccountList.value && authController.savedAccounts.isNotEmpty) {
      showAccountList.value = true;
    }
  }

  void goToCredentialsStep() {
    showLoginForm.value = true;
  }

  @override
  void onClose() {
    _dbWatcher?.dispose();
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    loginMode.value = _box.read<String>(_modeKey) ?? AccountModel.modeUser;
    _initAccountList();
    _autoLoadDatabasesIfPrefilled();
    _dbWatcher = ever<String>(
      authController.selectedDatabase,
      (_) => refreshEmployeeLoginAvailability(),
    );
  }

  /// Re-checks whether Employee sign-in is enabled for the selected server +
  /// database, and falls back to User mode when it isn't.
  Future<void> refreshEmployeeLoginAvailability() async {
    final host = urlController.text.trim();
    final db = authController.selectedDatabase.value;
    if (host.isEmpty || db.isEmpty) {
      employeeLoginEnabled.value = true;
      return;
    }

    final seq = ++_availabilityRequestSeq;
    final enabled = await EmployeeAuthService.fetchEmployeeLoginEnabled(
      baseUrl: selectedProtocol.value + host,
      db: db,
    );
    // A newer check (server/db changed meanwhile) wins; drop this result.
    if (seq != _availabilityRequestSeq) return;

    employeeLoginEnabled.value = enabled;
    if (!enabled && isEmployeeMode) {
      setLoginMode(AccountModel.modeUser);
    }
  }

  /// Loads the database list when the screen opens with an address already in
  /// the field.
  ///
  /// The list used to be fetched only when the user typed an address and hit
  /// the keyboard's Done key. Anyone arriving with a remembered address never
  /// triggered it, so the dropdown stayed empty and the Next button stayed
  /// dead — which is how the screen looked broken to Google Play's reviewer.
  void _autoLoadDatabasesIfPrefilled() {
    if (urlController.text.trim().isEmpty) return;
    if (authController.databases.isNotEmpty) return;
    // After the first frame so the spinner has something to render into.
    WidgetsBinding.instance.addPostFrameCallback((_) => fetchDatabases());
  }

  @override
  void onReady() {
    super.onReady();
    refreshAccountList();
  }

  Future<void> refreshAccountList() async {
    await authController.loadSavedAccounts();
    showAccountList.value = authController.savedAccounts.isNotEmpty;
    if (!showAccountList.value) {
      showLoginForm.value = false;
    }
    _applyPrefillAccountFromArguments();
  }

  void _applyPrefillAccountFromArguments() {
    final args = Get.arguments;
    if (args is! Map) return;
    final accountId = args['prefillAccountId'];
    if (accountId is! String || accountId.isEmpty) return;

    final account = authController.savedAccounts
        .firstWhereOrNull((entry) => entry.id == accountId);
    if (account == null) return;

    AuthDebug.log(
      'loginScreen:prefillAccount',
      {'user': account.username, 'id': account.id},
    );
    selectAccount(account);
  }

  Future<void> _initAccountList() async {
    await refreshAccountList();
    debugPrint('Saved accounts count: ${authController.savedAccounts.length}');
  }

  void showAddAccountForm() {
    showAccountList.value = false;
    showLoginForm.value = false;

    urlController.clear();
    usernameController.clear();
    passwordController.clear();
    selectedProtocol.value = 'https://';

    authController.databases.clear();
    authController.selectedDatabase.value = '';

    urlError.value = '';
    usernameError.value = '';
    passwordError.value = '';
    clearError();
  }

  void backToAccountList() {
    if (authController.savedAccounts.isNotEmpty) {
      showAccountList.value = true;
    }
  }

  void selectAccount(AccountModel account) {
    clearError();
    usernameError.value = '';
    passwordError.value = '';
    loginMode.value = account.loginMode;
    _box.write(_modeKey, account.loginMode);

    AuthDebug.log(
      'loginScreen:selectAccount',
      {'user': account.username, 'id': account.id},
    );

    var url = account.url;
    if (url.startsWith('https://')) {
      selectedProtocol.value = 'https://';
      url = url.substring(8);
    } else if (url.startsWith('http://')) {
      selectedProtocol.value = 'http://';
      url = url.substring(7);
    }
    urlController.text = url;

    authController.databases.value = [account.database];
    authController.selectedDatabase.value = account.database;

    usernameController.text = account.username;
    passwordController.clear();

    showAccountList.value = false;
    showLoginForm.value = true;
  }

  Future<void> removeSavedAccount(AccountModel account) async {
    await authController.removeAccount(account.id);
    await refreshAccountList();
    if (authController.savedAccounts.isEmpty) {
      showAccountList.value = false;
      showLoginForm.value = false;
    }
  }

}
