import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Shows a branded error dialog for 2FA verification failures.
Future<void> showTwoFactorErrorDialog({
  required String title,
  required String message,
  String? debugDetails,
  bool showDebugOption = false,
}) async {
  await Get.dialog<void>(
    _TwoFactorErrorDialog(
      title: title,
      message: message,
      debugDetails: debugDetails,
      showDebugOption: showDebugOption,
    ),
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
  );
}

class _TwoFactorErrorDialog extends StatefulWidget {
  const _TwoFactorErrorDialog({
    required this.title,
    required this.message,
    this.debugDetails,
    this.showDebugOption = false,
  });

  final String title;
  final String message;
  final String? debugDetails;
  final bool showDebugOption;

  @override
  State<_TwoFactorErrorDialog> createState() => _TwoFactorErrorDialogState();
}

class _TwoFactorErrorDialogState extends State<_TwoFactorErrorDialog> {
  bool _showDebug = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.style(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: AppTextStyles.style(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (widget.showDebugOption &&
                widget.debugDetails != null &&
                widget.debugDetails!.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _showDebug = !_showDebug),
                child: Text(
                  _showDebug
                      ? 'Hide technical details'
                      : 'Show technical details',
                  style: AppTextStyles.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (_showDebug)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.debugDetails!,
                      style: AppTextStyles.style(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.authbuttoncolor,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Get.back<void>(),
                child: Text(
                  'Try Again',
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
