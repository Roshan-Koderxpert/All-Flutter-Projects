import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/utils/logger.dart';
import '../../../routes/app_routes.dart';
import '../views/field_service_module_dialog.dart';

class AuthController extends GetxController {
  final AuthRepository _authRepository;

  AuthController(this._authRepository);

  // ── Form controllers ──────────────────────────
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // ── Observables ───────────────────────────────
  final isLoading         = false.obs;
  final isFetchingDb      = false.obs;
  final errorMessage      = ''.obs;
  final currentUser       = Rxn<UserModel>();

  // ── Server config state ───────────────────────
  final selectedProtocol  = 'https://'.obs;
  final selectedDatabase  = ''.obs;
  final databases         = <String>[].obs;

  // ── TOTP / 2FA state ──────────────────────────
  final isTotpLoading     = false.obs;
  final totpErrorMessage  = ''.obs;

  @override
  void onInit() {
    super.onInit();
    AppLogger.info('AuthController initialized', tag: 'AUTH_CTRL');
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  // ── Helpers ───────────────────────────────────
  bool get isLoggedIn => _authRepository.isLoggedIn;

  void clearError() => errorMessage.value = '';

  /// Normalizes pasted URLs (protocol in field + dropdown, paths, etc.).
  /// Returns the host-only string to show in the URL field.
  Future<String> fetchDatabases(String hostInput) async {
    clearError();
    isFetchingDb.value = true;
    databases.clear();
    selectedDatabase.value = '';

    var clean = hostInput.trim();
    var protocol = selectedProtocol.value;

    if (clean.startsWith('https://')) {
      protocol = 'https://';
      clean = clean.substring(8);
    } else if (clean.startsWith('http://')) {
      protocol = 'http://';
      clean = clean.substring(7);
    }

    // Host only (Odoo base is protocol + host; path belongs in reverse-proxy config)
    clean = clean.split('/').first.trim();
    selectedProtocol.value = protocol;

    if (clean.isEmpty) {
      isFetchingDb.value = false;
      errorMessage.value = 'Please enter server URL';
      return '';
    }

    final result = await _authRepository.fetchDatabases(
      protocol: protocol,
      host: clean,
    );

    isFetchingDb.value = false;

    if (result.success) {
      databases.assignAll(result.databases);
      selectedDatabase.value = result.databases.first;
      AppLogger.success('Databases loaded: ${result.databases}', tag: 'AUTH_CTRL');
    } else {
      errorMessage.value = result.errorMessage ?? 'Failed to fetch databases.';
      AppLogger.error(errorMessage.value, tag: 'AUTH_CTRL');
    }
    return clean;
  }

  // ── Step 2: Login with Odoo credentials ───────
  Future<void> login() async {
    FocusManager.instance.primaryFocus?.unfocus();
    clearError();

    if (selectedDatabase.value.trim().isEmpty) {
      errorMessage.value = 'Please select a database.';
      return;
    }

    isLoading.value = true;

    final result = await _authRepository.login(
      db:       selectedDatabase.value,
      username: usernameController.text.trim(),
      password: passwordController.text,
    );

    isLoading.value = false;

    if (result.moduleNotInstalled) {
      await _handleFieldServiceModuleMissing(fromTotp: false);
    } else if (result.success && result.user != null) {
      currentUser.value = result.user;
      AppLogger.success('Login OK → dashboard', tag: 'AUTH_CTRL');
      Get.offAllNamed(AppRoutes.dashboard);
    } else if (result.totpRequired) {
      AppLogger.info('TOTP required → totp screen', tag: 'AUTH_CTRL');
      Get.toNamed(AppRoutes.totp);
    } else {
      errorMessage.value =
          result.errorMessage ?? 'Login failed. Please try again.';
      AppLogger.error(errorMessage.value, tag: 'AUTH_CTRL');
    }
  }

  // ── Step 3: Verify TOTP code ──────────────────
  Future<void> verifyTotp(String code) async {
    FocusManager.instance.primaryFocus?.unfocus();
    totpErrorMessage.value = '';
    isTotpLoading.value = true;

    final result = await _authRepository.verifyTotp(
      code:     code,
      db:       selectedDatabase.value,
    );

    isTotpLoading.value = false;

    if (result.moduleNotInstalled) {
      await _handleFieldServiceModuleMissing(fromTotp: true);
    } else if (result.success && result.user != null) {
      currentUser.value = result.user;
      AppLogger.success('TOTP OK → dashboard', tag: 'AUTH_CTRL');
      Get.offAllNamed(AppRoutes.dashboard);
    } else {
      totpErrorMessage.value =
          result.errorMessage ?? 'Invalid authentication code. Please try again.';
      AppLogger.error(totpErrorMessage.value, tag: 'AUTH_CTRL');
    }
  }

  Future<void> _handleFieldServiceModuleMissing({required bool fromTotp}) async {
    passwordController.clear();
    currentUser.value = null;
    errorMessage.value = '';
    totpErrorMessage.value = '';

    await FieldServiceModuleDialog.show(
      onBackToLogin: () {
        Get.back();
        if (fromTotp) {
          Get.offAllNamed(AppRoutes.login);
        }
      },
    );
  }

  void clearTotpError() => totpErrorMessage.value = '';

  // ── Logout ────────────────────────────────────
  Future<void> logout() async {
    await _authRepository.logout();
    currentUser.value = null;
    usernameController.clear();
    passwordController.clear();
    databases.clear();
    selectedDatabase.value = '';
    errorMessage.value = '';
    Get.offAllNamed(AppRoutes.login);
  }
}