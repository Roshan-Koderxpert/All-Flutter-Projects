import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  static bool _authInProgress = false;
  static DateTime? _lastAuthSuccessTime;

  /// Skip resume lock when auth just finished (e.g. system dialog closing).
  static bool shouldSuppressResumeLock() {
    if (_authInProgress) return true;
    final lastSuccess = _lastAuthSuccessTime;
    if (lastSuccess == null) return false;
    return DateTime.now().difference(lastSuccess) <
        const Duration(seconds: 5);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Error checking device support: $e');
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  static String getBiometricTypeName(List<BiometricType> types) {
    if (types.isEmpty) return 'Device passcode';

    final names = <String>[];
    if (types.contains(BiometricType.face)) names.add('Face ID');
    if (types.contains(BiometricType.fingerprint)) names.add('Fingerprint');
    if (types.contains(BiometricType.iris)) names.add('Iris');
    if (types.contains(BiometricType.strong)) names.add('Strong Biometric');
    if (types.contains(BiometricType.weak)) names.add('Weak Biometric');

    return names.join(', ');
  }

  /// Returns `true` on success, `false` on failure/cancel, `null` if unavailable.
  static Future<bool?> authenticate({
    String reason = 'Please authenticate to access the app',
    bool stickyAuth = true,
    bool biometricOnly = false,
  }) async {
    if (_authInProgress) {
      debugPrint('Biometric authentication already in progress');
      return false;
    }

    _authInProgress = true;
    try {
      if (!await isDeviceSupported()) {
        debugPrint('Device does not support local authentication');
        return null;
      }

      final availableBiometrics = await getAvailableBiometrics();
      debugPrint(
        'Available biometrics: ${getBiometricTypeName(availableBiometrics)}',
      );

      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: stickyAuth,
        sensitiveTransaction: true,
      );

      if (didAuthenticate) {
        _lastAuthSuccessTime = DateTime.now();
      }

      return didAuthenticate;
    } on LocalAuthException catch (e) {
      debugPrint(
        'Biometric authentication error: ${e.code.name} - ${e.description}',
      );
      return _mapLocalAuthException(e.code);
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: ${e.code} - ${e.message}');
      return _mapPlatformException(e.code);
    } catch (e) {
      debugPrint('Unexpected error during authentication: $e');
      return false;
    } finally {
      _authInProgress = false;
    }
  }

  static bool? _mapLocalAuthException(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return false;
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.uiUnavailable:
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return null;
      case LocalAuthExceptionCode.authInProgress:
      case LocalAuthExceptionCode.userRequestedFallback:
        return false;
    }
  }

  static bool? _mapPlatformException(String code) {
    switch (code) {
      case 'NotAvailable':
      case 'NotEnrolled':
      case 'PasscodeNotSet':
      case 'OtherOperatingSystem':
        return null;
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return false;
      default:
        return false;
    }
  }

  static Future<bool> canEnableBiometric() async {
    return isDeviceSupported();
  }
}
