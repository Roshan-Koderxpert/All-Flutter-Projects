import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class BiometricStatusDialog extends StatelessWidget {
  const BiometricStatusDialog({super.key, required this.enabled});

  final bool enabled;

  static Future<void> show(BuildContext context, {required bool enabled}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BiometricStatusDialog(enabled: enabled),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconBgColor = enabled ? const Color(0xFF16A34A) : AppColors.brandBlue;

    return Dialog(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                enabled ? Icons.fingerprint_rounded : Icons.lock_open_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              enabled ? 'Biometric Enabled' : 'Biometric Disabled',
              textAlign: TextAlign.center,
              style: AppTextStyles.style(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              enabled
                  ? 'You will be asked to authenticate with biometrics when opening the app.'
                  : 'Biometric authentication has been turned off. You can enable it again anytime from Settings.',
              textAlign: TextAlign.center,
              style: AppTextStyles.style(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Got it',
                  style: AppTextStyles.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
