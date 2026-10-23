import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/login_controller.dart';

/// "Forgot password?" bottom sheet, shared by both sign-in modes.
///
/// User mode hands off to Odoo's own password-reset page in the device
/// browser. Employee mode requests a reset email through the module's
/// self-service endpoint. Either way, this sheet only *requests* the reset —
/// the employee finishes it by following the emailed link.
class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({super.key});

  static Future<void> show() {
    final controller = Get.find<LoginController>();
    controller.clearResetRequestState();
    return Get.bottomSheet(
      // Get.bottomSheet builds its own route and takes neither
      // bottomSheetTheme nor a constraints argument, so the tablet cap is
      // applied to the sheet content itself.
      const ResponsiveBody(child: ForgotPasswordSheet()),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  late final LoginController controller;
  late final TextEditingController emailController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<LoginController>();
    emailController =
        TextEditingController(text: controller.forgotPasswordInitialEmail);
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = emailController.text.trim();
    if (controller.isEmployeeMode) {
      controller.requestEmployeePasswordReset(email);
    } else {
      controller.requestUserPasswordReset(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Obx(() {
            final done = controller.resetRequestMessage.value.isNotEmpty;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Reset your password',
                  style: AppTextStyles.style(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  controller.isEmployeeMode
                      ? "Enter the email you sign in with as an Employee. "
                          "If it's registered, we'll send a link to reset your password."
                      : "Enter your account email. We'll open your browser to "
                          "Odoo's password reset page.",
                  style: AppTextStyles.style(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                if (!done) ...[
                  Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCCCCCC)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: AppTextStyles.style(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: AppTextStyles.style(
                          fontSize: 14,
                          color: const Color(0xFFCCCCCC),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (controller.resetRequestError.value.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.resetRequestError.value,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                        controller.isRequestingReset.value ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.authbuttoncolor,
                      disabledBackgroundColor: AppColors.authbuttoncolor,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: controller.isRequestingReset.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            controller.isEmployeeMode
                                ? 'Send reset link'
                                : 'Open reset page',
                            style: AppTextStyles.button,
                          ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.resetRequestMessage.value,
                            style: AppTextStyles.style(
                              fontSize: 13,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.authbuttoncolor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Done', style: AppTextStyles.button),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}
