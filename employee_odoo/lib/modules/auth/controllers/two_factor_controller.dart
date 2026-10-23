import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../app/routes/app_routes.dart';
import '../../../data/repositories/mobile_access_repository.dart';
import '../../../data/services/odoo_auth_service.dart';
import '../../../data/services/odoo_totp_service.dart';
import '../../../data/services/totp_debug_log.dart';
import '../widgets/two_factor_error_dialog.dart';
import 'auth_controller.dart';

class TwoFactorController extends GetxController {
  TwoFactorController();

  final AuthController authController = Get.find<AuthController>();

  final List<TextEditingController> digitControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController passwordController = TextEditingController();

  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final debugDetails = ''.obs;
  final focusRevision = 0.obs;
  final awaitCredentials = false.obs;
  final obscurePassword = true.obs;

  late String baseUrl;
  late String db;
  late String login;
  late String password;
  late String sessionId;
  late String flow;
  String? accountId;

  bool get isAddAccountFlow => flow == 'addAccount';
  bool get isSwitchAccountFlow => flow == 'switchAccount';

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>;
    baseUrl = args['baseUrl'] as String;
    db = args['db'] as String;
    login = args['login'] as String;
    password = args['password'] as String? ?? '';
    sessionId = args['sessionId'] as String? ?? '';
    flow = args['flow'] as String? ?? 'login';
    accountId = args['accountId'] as String?;
    awaitCredentials.value =
        args['awaitCredentials'] as bool? ?? (isAddAccountFlow && password.isEmpty);

    if (password.isNotEmpty) {
      passwordController.text = password;
    }

    for (final node in focusNodes) {
      node.addListener(() => focusRevision.value++);
    }

    if (!awaitCredentials.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focusNodes.isNotEmpty) {
          focusNodes[0].requestFocus();
        }
      });
    }
  }

  @override
  void onClose() {
    for (final c in digitControllers) {
      c.dispose();
    }
    for (final f in focusNodes) {
      f.dispose();
    }
    passwordController.dispose();
    super.onClose();
  }

  String get otpCode => digitControllers.map((c) => c.text).join();

  void onDigitChanged(int index, String value) {
    errorMessage.value = '';

    if (value.length == 6) {
      for (var i = 0; i < 6; i++) {
        digitControllers[i].text = value[i];
      }
      focusNodes[5].requestFocus();
      verifyCode();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    }

    if (value.isNotEmpty && index == 5) {
      focusNodes[5].unfocus();
      verifyCode();
    }
  }

  void onKeyBackspace(int index) {
    if (digitControllers[index].text.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
      digitControllers[index - 1].clear();
    }
  }

  void clearCode() {
    _clearDigitsOnly();
    errorMessage.value = '';
    debugDetails.value = '';
  }

  void _clearDigitsOnly() {
    for (final c in digitControllers) {
      c.clear();
    }
  }

  Future<void> submitAddAccountCredentials() async {
    final enteredPassword = passwordController.text;
    if (enteredPassword.isEmpty) {
      errorMessage.value = 'Please enter your password';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      password = enteredPassword;
      final attempt = await OdooAuthService.attemptAuthenticate(
        baseUrl: baseUrl,
        db: db,
        login: login,
        password: password,
      );

      if (attempt.requiresTotp) {
        sessionId = attempt.partialSessionId ?? '';
        awaitCredentials.value = false;
        isLoading.value = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNodes.isNotEmpty) {
            focusNodes[0].requestFocus();
          }
        });
        return;
      }

      if (attempt.session == null || attempt.session!.userId <= 0) {
        throw OdooException('Authentication failed');
      }

      await authController.completeAddAccount(
        baseUrl: baseUrl,
        db: db,
        username: login,
        password: password,
        session: attempt.session!,
      );
      _finishAddAccountSuccess();
    } on OdooException catch (e) {
      errorMessage.value = _mapCredentialError(e);
    } catch (e) {
      errorMessage.value = _mapCredentialError(e);
    } finally {
      isLoading.value = false;
    }
  }

  String _mapCredentialError(Object e) {
    final message = e.toString().toLowerCase();
    if (message.contains('invalid') ||
        message.contains('401') ||
        message.contains('access denied') ||
        message.contains('wrong login')) {
      return 'Incorrect username or password';
    }
    if (message.contains('timeout') || message.contains('socket')) {
      return 'Connection error. Check your network.';
    }
    return 'Could not sign in. Please try again.';
  }

  Future<void> verifyCode() async {
    final code = otpCode.replaceAll(RegExp(r'\s'), '');
    if (code.length < 6) {
      await _showVerificationError(
        title: 'Incomplete code',
        message: 'Please enter all 6 digits from your authenticator app.',
        errorCode: 'incomplete_code',
      );
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    debugDetails.value = '';

    final debugLog = TotpDebugLog();

    try {
      final verifyResult = await OdooTotpService.verifyTotpCode(
        baseUrl: baseUrl,
        sessionId: sessionId,
        code: code,
        db: db,
        login: login,
        password: password,
        log: debugLog,
      );

      if (verifyResult.success && verifyResult.sessionId != null) {
        if (isAddAccountFlow) {
          await authController.completeAddAccountAfterTotp(
            baseUrl: baseUrl,
            db: db,
            username: login,
            password: password,
            sessionId: verifyResult.sessionId!,
            sessionInfo: verifyResult.sessionInfo,
          );
          _finishAddAccountSuccess();
        } else if (isSwitchAccountFlow) {
          await authController.completeSwitchAccountAfterTotp(
            baseUrl: baseUrl,
            db: db,
            username: login,
            password: password,
            sessionId: verifyResult.sessionId!,
            accountId: accountId!,
            sessionInfo: verifyResult.sessionInfo,
          );
          _finishSwitchAccountSuccess();
        } else {
          await authController.completeLoginAfterTotp(
            baseUrl: baseUrl,
            db: db,
            username: login,
            password: password,
            sessionId: verifyResult.sessionId!,
            sessionInfo: verifyResult.sessionInfo,
          );
        }
      } else {
        isLoading.value = false;
        await _setFailure(
          verifyResult.message ?? 'Invalid code. Please try again.',
          verifyResult.debugLog ?? debugLog,
          verifyResult.errorCode,
        );
      }
    } catch (e, st) {
      debugLog.error('controller', e, st);
      isLoading.value = false;
      if (e is MobileAccessDeniedException) {
        await _setFailure(e.message, debugLog, 'mobile_access_denied');
        return;
      }
      final msg = e.toString();
      if (msg.contains('not fully authenticated')) {
        await _setFailure(
          'Code accepted but session could not be started. Please sign in again.',
          debugLog,
          'session_not_authenticated',
        );
      } else if (msg.contains('SocketException') ||
          msg.contains('TimeoutException')) {
        await _setFailure(
          'Could not reach the server. Check your internet connection and try again.',
          debugLog,
          'network',
        );
      } else {
        await _setFailure(
          'Something went wrong during verification. Please try again.',
          debugLog,
          'exception',
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _finishSwitchAccountSuccess() {
    Get.snackbar(
      'Account',
      'Switched to $login',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFC8E6C9),
      colorText: const Color(0xFF1B5E20),
    );
    Get.offAllNamed(AppRoutes.home);
  }

  void _finishAddAccountSuccess() {
    Get.snackbar(
      'Account',
      'Switched to $login',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFC8E6C9),
      colorText: const Color(0xFF1B5E20),
    );
    Get.offAllNamed(AppRoutes.home);
  }

  Future<void> _setFailure(
    String message,
    TotpDebugLog log,
    String? errorCode,
  ) async {
    debugDetails.value = log.summary;
    errorMessage.value = message;
    _clearDigitsOnly();
    await _showVerificationError(
      title: _titleForError(errorCode),
      message: message,
      errorCode: errorCode,
    );
  }

  Future<void> _showVerificationError({
    required String title,
    required String message,
    String? errorCode,
  }) async {
    isLoading.value = false;
    final isWrongCode =
        errorCode == 'invalid_code' || errorCode == 'incomplete_code';
    await showTwoFactorErrorDialog(
      title: title,
      message: message,
      debugDetails: debugDetails.value,
      showDebugOption: !isWrongCode && debugDetails.value.isNotEmpty,
    );
    focusNodes[0].requestFocus();
  }

  String _titleForError(String? errorCode) {
    return switch (errorCode) {
      'invalid_code' => 'Incorrect authentication code',
      'incomplete_code' => 'Incomplete code',
      'csrf_missing' || 'csrf_rejected' || 'http_400' => 'Session expired',
      'bootstrap_failed' => 'Could not start 2FA',
      'session_not_authenticated' => 'Session error',
      'network' => 'Connection error',
      _ => 'Verification failed',
    };
  }
}
