import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_asset_image.dart';
import '../../../core/widgets/app_back_button.dart';
import '../controllers/two_factor_controller.dart';

class TwoFactorView extends GetView<TwoFactorController> {
  const TwoFactorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 48),
                      AppAssetImage(
                        assetPath: AppImage.logo,
                        width: 240,
                        height: 72,
                        fallback: const Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: AppColors.brandBlue,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Obx(() {
                        if (controller.awaitCredentials.value) {
                          return _buildAddAccountCredentialsStep();
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildShieldIcon(),
                            const SizedBox(height: 24),
                            Text(
                              controller.isAddAccountFlow
                                  ? 'Two-Factor Authentication'
                                  : 'Two-Factor Authentication',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.style(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              controller.isAddAccountFlow
                                  ? 'Enter your password and authenticator code\nfor ${controller.login}'
                                  : 'Enter the 6-digit code from your\nauthenticator app',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.style(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            _buildOtpFields(),
                            const SizedBox(height: 16),
                            Obx(() {
                              if (controller.errorMessage.isEmpty) {
                                return const SizedBox(height: 20);
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  controller.errorMessage.value,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.style(
                                    color: AppColors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            _buildVerifyButton(),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: controller.clearCode,
                              child: Text(
                                'Clear Code',
                                style: AppTextStyles.style(
                                  color: AppColors.authbuttoncolor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 8,
              left: 4,
              child: AppBackButton(color: AppColors.authbuttoncolor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAccountCredentialsStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildShieldIcon(),
        const SizedBox(height: 24),
        Text(
          'Sign in to add account',
          textAlign: TextAlign.center,
          style: AppTextStyles.style(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter the password for\n${controller.login}',
          textAlign: TextAlign.center,
          style: AppTextStyles.style(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Obx(
          () => TextField(
            controller: controller.passwordController,
            obscureText: controller.obscurePassword.value,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!controller.isLoading.value) {
                controller.submitAddAccountCredentials();
              }
            },
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => controller.obscurePassword.toggle(),
                icon: Icon(
                  controller.obscurePassword.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          if (controller.errorMessage.isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              controller.errorMessage.value,
              textAlign: TextAlign.center,
              style: AppTextStyles.style(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Obx(
          () {
            final loading = controller.isLoading.value;
            return SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.authbuttoncolor,
                  disabledBackgroundColor:
                      AppColors.authbuttoncolor.withValues(alpha: 0.85),
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    loading ? null : controller.submitAddAccountCredentials,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        'Continue',
                        style: AppTextStyles.style(
                          fontSize: 16,
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShieldIcon() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.authbuttoncolor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.authbuttoncolor.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.shield_outlined,
        color: AppColors.authbuttoncolor,
        size: 36,
      ),
    );
  }

  Widget _buildOtpFields() {
    return Obx(() {
      // Rebuild when focus or error state changes.
      final _ = controller.focusRevision.value;
      final hasError = controller.errorMessage.isNotEmpty;
      return Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent ||
              event.logicalKey != LogicalKeyboardKey.backspace) {
            return KeyEventResult.ignored;
          }
          final focusedIndex =
              controller.focusNodes.indexWhere((n) => n.hasFocus);
          if (focusedIndex >= 0 &&
              controller.digitControllers[focusedIndex].text.isEmpty) {
            controller.onKeyBackspace(focusedIndex);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _buildSingleDigitField(index, hasError: hasError),
            );
          }),
        ),
      );
    });
  }

  Widget _buildSingleDigitField(int index, {required bool hasError}) {
    final isFocused = controller.focusNodes[index].hasFocus;

    final borderColor = hasError
        ? AppColors.error
        : isFocused
        ? AppColors.authbuttoncolor
        : AppColors.border;

    final borderWidth = isFocused ? 2.5 : 1.5;

    return Material(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 48,
        height: 52,
        child: Center(                                  // ✅ Center widget wraps TextField
          child: TextField(
            controller: controller.digitControllers[index],
            focusNode: controller.focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            maxLength: index == 0 ? 6 : 1,
            cursorColor: AppColors.authbuttoncolor,
            cursorHeight: 22,                           // ✅ explicit cursor height
            style: AppTextStyles.style(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.0,                              // ✅ tight line height
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              isCollapsed: true,                        // ✅ collapses default padding
              contentPadding: EdgeInsets.zero,          // ✅ no extra padding
            ),
            onChanged: (value) => controller.onDigitChanged(index, value),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return Obx(
      () {
        final loading = controller.isLoading.value;
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.authbuttoncolor,
              disabledBackgroundColor:
                  AppColors.authbuttoncolor.withValues(alpha: 0.85),
              foregroundColor: AppColors.white,
              disabledForegroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: loading ? null : controller.verifyCode,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    'VERIFY',
                    style: AppTextStyles.style(
                      fontSize: 16,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
