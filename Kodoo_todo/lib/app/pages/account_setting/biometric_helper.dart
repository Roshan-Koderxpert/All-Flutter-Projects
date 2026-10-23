import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if biometric authentication is enabled in app settings
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  /// Save biometric enabled state
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  /// Check if device supports biometric authentication
  static Future<bool> isDeviceSupported() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      print("❌ Error checking device support: $e");
      return false;
    }
  }

  /// Get available biometric types on the device
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      print("❌ Error getting available biometrics: $e");
      return [];
    }
  }

  /// Get human-readable biometric type names
  static String getBiometricTypeName(List<BiometricType> types) {
    if (types.isEmpty) return "None";

    List<String> names = [];
    if (types.contains(BiometricType.face)) names.add("Face ID");
    if (types.contains(BiometricType.fingerprint)) names.add("Fingerprint");
    if (types.contains(BiometricType.iris)) names.add("Iris");
    if (types.contains(BiometricType.strong)) names.add("Strong Biometric");
    if (types.contains(BiometricType.weak)) names.add("Weak Biometric");

    return names.join(", ");
  }

  /// Main authentication method
  /// Returns:
  /// - true: Authentication successful
  /// - false: Authentication failed or cancelled
  /// - null: Device doesn't support biometrics or none enrolled
  static Future<bool?> authenticate({
    String reason = 'Please authenticate to access the app',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool biometricOnly = false,
  }) async {
    try {
      // Check if device supports biometrics
      final bool isSupported = await isDeviceSupported();
      if (!isSupported) {
        print("⚠️ Device doesn't support biometric authentication");
        return null; // Device doesn't support
      }

      // Check if any biometrics are enrolled
      final List<BiometricType> availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        print("⚠️ No biometrics enrolled on device");
        return null; // No biometrics enrolled
      }

      print("🔐 Available biometrics: ${getBiometricTypeName(availableBiometrics)}");

      // Perform authentication using the simplest API call
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
      );

      if (didAuthenticate) {
        print("✅ Biometric authentication successful");
        return true;
      } else {
        print("❌ Biometric authentication failed");
        return false;
      }
    } on PlatformException catch (e) {
      print("❌ Biometric authentication error: ${e.code} - ${e.message}");

      // Handle specific error codes
      if (e.code == 'NotAvailable') {
        print("⚠️ Biometric hardware not available");
        return null;
      } else if (e.code == 'NotEnrolled' || e.code == 'PasscodeNotSet') {
        print("⚠️ No biometrics enrolled");
        return null;
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        print("🔒 Biometric authentication locked");
        return false;
      } else if (e.code == 'OtherOperatingSystem') {
        print("⚠️ Not available on this OS");
        return null;
      }

      return false;
    } catch (e) {
      print("❌ Unexpected error during authentication: $e");
      return false;
    }
  }

  /// Authenticate on app start
  /// Returns true if authentication passed or not needed
  /// Returns false if authentication failed
  static Future<bool> authenticateOnAppStart() async {
    try {
      // Check if biometric is enabled in settings
      final bool biometricEnabled = await isBiometricEnabled();

      if (!biometricEnabled) {
        print("ℹ️ Biometric authentication not enabled in settings");
        return true; // Not enabled, so allow access
      }

      print("🔐 Biometric authentication is enabled, authenticating...");

      // Perform authentication
      final bool? result = await authenticate(
        reason: 'Authenticate to access Kodoo CRM',
        useErrorDialogs: true,
        stickyAuth: true,
        biometricOnly: false, // Allow PIN/Pattern as fallback
      );

      // Handle different results
      if (result == null) {
        // Device doesn't support or no biometrics enrolled
        print("⚠️ Biometric not available, allowing access");
        return true; // Allow access
      } else if (result == true) {
        // Authentication successful
        print("✅ Authentication successful");
        return true;
      } else {
        // Authentication failed
        print("❌ Authentication failed");
        return false;
      }
    } catch (e) {
      print("❌ Error in authenticateOnAppStart: $e");
      return true; // On error, allow access (fail-safe)
    }
  }

  /// Check and prompt user to enable biometrics when toggling setting
  static Future<bool> canEnableBiometric() async {
    final bool isSupported = await isDeviceSupported();

    if (!isSupported) {
      return false;
    }

    final List<BiometricType> availableBiometrics = await getAvailableBiometrics();

    if (availableBiometrics.isEmpty) {
      return false;
    }

    return true;
  }

  /// Test authentication (for testing purposes)
  static Future<void> testAuthentication() async {
    print("🧪 Testing biometric authentication...");

    final bool isSupported = await isDeviceSupported();
    print("Device supported: $isSupported");

    if (!isSupported) {
      print("❌ Device doesn't support biometrics");
      return;
    }

    final List<BiometricType> types = await getAvailableBiometrics();
    print("Available biometrics: ${getBiometricTypeName(types)}");

    if (types.isEmpty) {
      print("❌ No biometrics enrolled");
      return;
    }

    final bool? result = await authenticate(
      reason: 'Testing biometric authentication',
    );

    print("Authentication result: $result");
  }
}