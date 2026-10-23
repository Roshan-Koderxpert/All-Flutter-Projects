import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

/// Centralises the runtime permission requests the app needs.
///
/// The native manifests already *declare* every permission the app uses
/// (see `AndroidManifest.xml` and `ios/Runner/Info.plist`): location
/// (fine/coarse/background), foreground-service, notifications, camera and
/// biometrics. This service asks the user, at runtime, for the ones that must
/// be granted before the related feature works.
///
/// Camera / photo-library / file access is requested *contextually* by
/// `image_picker` / `file_picker` when the user opens those screens (the
/// platform-recommended pattern), so it is intentionally not forced at startup.
class PermissionService {
  PermissionService._();

  static bool _startupRequested = false;

  /// Requests the permissions needed for the app's core features, once per
  /// app launch. Safe to call repeatedly — it no-ops after the first run and
  /// never throws.
  ///
  /// Deliberately does **not** ask for location. Google Play's Prominent
  /// Disclosure policy requires the in-app disclosure to be shown and accepted
  /// *before* the OS location prompt appears; asking here fired that prompt on
  /// app launch with no disclosure in front of it, which is what got the app
  /// pulled from Play. Location is now requested only from the check-in flow
  /// and the Settings toggle, both of which run `RouteTrackingConsent` first.
  /// Do not add a location request to this method.
  static Future<void> requestStartupPermissions() async {
    if (_startupRequested) return;
    _startupRequested = true;
    await _requestNotifications();
  }

  static Future<void> _requestNotifications() async {
    try {
      // Android 13+ POST_NOTIFICATIONS — also required for the route-tracking
      // foreground-service notification.
      await FlutterForegroundTask.requestNotificationPermission();
    } catch (e) {
      debugPrint('PermissionService: notification request failed: $e');
    }
  }

  // NOTE: there is deliberately no `requestLocation()` helper here. The only
  // place allowed to trigger the OS location prompt is `_prepareTracking()` in
  // HomeController, which runs after `RouteTrackingConsent` has shown the
  // prominent disclosure and the user has accepted it. Routing location
  // requests through a general-purpose helper is how the pre-disclosure prompt
  // crept in; keep the request at the one call site that owns the disclosure.

  /// Whether the location service is on and foreground permission is granted,
  /// without prompting the user. Used to decide if route tracking can start.
  static Future<bool> hasUsableLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}
