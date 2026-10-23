import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

TextSpan _boldSpan(String text) => TextSpan(
      text: text,
      style: AppTextStyles.style(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );

/// Stores and prompts for the user's consent to background route tracking.
///
/// Continuous location tracking is sensitive, so nothing is recorded until the
/// user explicitly agrees. Consent can be withdrawn from Settings.
class RouteTrackingConsent {
  RouteTrackingConsent._();

  static const String storageKey = 'route_tracking_consent';
  static final GetStorage _box = GetStorage();

  static bool get isGranted => _box.read(storageKey) == true;

  static Future<void> setGranted(bool value) => _box.write(storageKey, value);

  /// Ensures consent, showing the disclosure if it hasn't been accepted yet.
  /// Returns whether consent is now granted.
  static Future<bool> ensureConsent() async {
    if (isGranted) return true;
    final granted = await requestConsent();
    if (granted) await setGranted(true);
    return granted;
  }

  /// Shows the prominent disclosure and returns the user's answer.
  ///
  /// Google Play's Prominent Disclosure and Consent policy requires this to run
  /// *before* the runtime location permission prompt, on **every** path that
  /// opts the user into location collection — the check-in flow and the
  /// Settings toggle both call it. The wording is deliberate: it names the app,
  /// says it *collects* location data, states what it is used for, and spells
  /// out that collection continues in the background. Do not soften those
  /// phrases without re-reading the policy.
  static Future<bool> requestConsent() async {
    final result = await Get.dialog<bool>(
      Dialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.brandBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Allow Location Tracking',
                textAlign: TextAlign.center,
                style: AppTextStyles.style(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text.rich(
                    TextSpan(
                      style: AppTextStyles.style(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                      children: [
                        // First sentence follows Google's prescribed format
                        // verbatim: "[App] collects [data] to enable
                        // [feature], [in what scenario]." Keep "collects",
                        // "to enable" and the background phrase intact.
                        _boldSpan(AppConstants.appName),
                        const TextSpan(text: ' '),
                        _boldSpan('collects location data'),
                        const TextSpan(
                          text: ' to enable attendance route tracking, ',
                        ),
                        _boldSpan(
                          'even when the app is closed or not in use',
                        ),
                        const TextSpan(
                          text: '.\n\nYour work route is recorded between '
                              'check-in and check-out and saved to your '
                              "employer's attendance records. Collection "
                              'starts when you check in and stops '
                              'automatically when you check out.\n\nYou can '
                              'turn this off at any time in Settings.',
                        ),
                      ],
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(result: false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Decline',
                        style: AppTextStyles.style(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Allow',
                        style: AppTextStyles.style(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    final granted = result == true;
    if (granted) await setGranted(true);
    return granted;
  }
}
