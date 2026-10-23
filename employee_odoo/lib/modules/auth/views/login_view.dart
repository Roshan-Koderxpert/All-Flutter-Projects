import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_asset_image.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../data/models/account_model.dart';
import '../controllers/auth_controller.dart';
import '../controllers/login_controller.dart';
import '../widgets/forgot_password_sheet.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  static const double _logoHeight = 80;
  static const double _logoCardGap = 20;
  /// Used only to anchor logo/card on screen — not applied to the card widget.
  static const double _layoutAnchorCardHeight = 280;
  static const double _contentUpOffset = 64;

  AuthController get auth => controller.authController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Obx(
          () => Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final blockHeight = _logoHeight +
                        _logoCardGap +
                        _layoutAnchorCardHeight;
                    final logoTop =
                        ((constraints.maxHeight - blockHeight) / 2 -
                                _contentUpOffset)
                            .clamp(
                      0.0,
                      double.infinity,
                    );
                    final cardTop = logoTop + _logoHeight + _logoCardGap;

                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          width: double.infinity,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: logoTop,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: AppAssetImage(
                                    assetPath: AppImage.logo,
                                    width: 240,
                                    height: _logoHeight,
                                    fallback: const Icon(
                                      Icons.image_outlined,
                                      size: 48,
                                      color: AppColors.brandBlue,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: cardTop,
                                left: 0,
                                right: 0,
                                child: _buildSignInCard(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (controller.showLoginForm.value || (!controller.showAccountList.value && auth.savedAccounts.isNotEmpty))                Positioned(
                  top: 8,
                  left: 12,
                  child: GestureDetector(
                    onTap: controller.goBackToServerConfig,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInCard() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 342),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 2,
                spreadRadius: 0,
                offset: Offset.zero,
              ),
            ],
          ),
          child: _buildCardContent(),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.signIn, textAlign: TextAlign.center, style: AppTextStyles.displayLarge),
        const SizedBox(height: 8),
        Obx(
              () => Text(
            controller.showAccountList.value
                ? 'Choose an account to continue'
                : controller.showLoginForm.value
                ? AppStrings.loginCredentialSubtitle
                : AppStrings.loginServerSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium,
          ),
        ),
        const SizedBox(height: 24),
        Obx(
              () => controller.showAccountList.value
              ? _buildAccountList()
              : controller.showLoginForm.value
              ? _buildLoginForm()
              : _buildServerConfig(),
        ),
      ],
    );
  }

  Widget _buildAccountList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => Column(
            children: auth.savedAccounts
                .map((account) => _buildAccountTile(account))
                .toList(),
          ),
        ),
        Obx(
              () => controller.errorMessage.value.isNotEmpty
              ? Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              controller.errorMessage.value,
              style: AppTextStyles.style(color: AppColors.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: controller.showAddAccountForm,
          child: Text(
            'Add another account',
            style: AppTextStyles.style(color: AppColors.authbuttoncolor, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTile(AccountModel account) {
    final avatarImage = _decodeAvatar(account.image1920);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => controller.selectAccount(account),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCCCCCC)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppColors.authbuttoncolor.withValues(alpha: 0.15),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Text(
                          (account.name?.isNotEmpty == true
                                  ? account.name!
                                  : account.username)[0]
                              .toUpperCase(),
                          style: AppTextStyles.style(
                            color: AppColors.authbuttoncolor,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name?.isNotEmpty == true
                            ? account.name!
                            : account.username,
                        style: AppTextStyles.style(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        account.email?.isNotEmpty == true
                            ? account.email!
                            : account.url,
                        style: AppTextStyles.style(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (account.database.isNotEmpty)
                        Text(
                          account.database,
                          style: AppTextStyles.style(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove account',
                  onPressed: () => _confirmRemoveAccount(account),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemoveAccount(AccountModel account) {
    Get.defaultDialog(
      title: 'Remove account',
      middleText: 'Remove "${account.username}" from this device?',
      textCancel: 'Cancel',
      textConfirm: 'Remove',
      confirmTextColor: Colors.white,
      onConfirm: () {
        Get.back();
        controller.removeSavedAccount(account);
      },
    );
  }

  Widget _buildServerConfig() {
    return Column(
      children: [
        _buildServerUrlField(),
        Obx(
          () => controller.urlError.value.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      controller.urlError.value,
                      style: AppTextStyles.style(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        _buildDatabaseDropdown(),
        const SizedBox(height: 20),
        Obx(
          () => _buildPrimaryButton(
            // Never `null`. A permanently dead button is what Google Play
            // flagged as "unresponsive UI elements": with no database loaded
            // the old button simply ignored every tap and said nothing. It now
            // always responds — loading the database list if that hasn't
            // happened yet, and otherwise explaining what is missing.
            onPressed: controller.isFetchingDb.value
                ? null
                : _handleNextPressed,
            child: controller.isFetchingDb.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primaryButtonForeground,
                    ),
                  )
                : Text(
                    AppStrings.next,
                    style: AppTextStyles.button.copyWith(
                      color: _primaryButtonForeground,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildServerUrlField() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppAssetImage(
            assetPath: AppIcon.url,
            width: 18,
            height: 18,
            color: Colors.black,
            fallback: const Icon(Icons.link, size: 18, color: Colors.black),
          ),
          const SizedBox(width: 8),
          Obx(
            () => DropdownButtonHideUnderline(
              child: AppDropdownButton<String>(
                isDense: true,
                value: controller.selectedProtocol.value,
                icon: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: AppAssetImage(
                    assetPath: AppImage.arrowDown,
                    width: 20,
                    height: 20,
                    fallback: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  ),
                ),
                items: const ['http://', 'https://']
                    .map(
                      (protocol) => AppDropdownStyle.item(
                        value: protocol,
                        child: Text(
                          protocol,
                          style: AppTextStyles.style(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.selectedProtocol.value = value;
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 5),
          Container(height: 24, width: 1, color: const Color(0xFFDDDDDD)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller.urlController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _fetchDatabases(),
              style: AppTextStyles.style(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter Server Address',
                hintStyle: AppTextStyles.style(
                  fontSize: 14,
                  color: const Color(0xFFCCCCCC),
                ),
                border: InputBorder.none,
                isDense: true,
                filled: false,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          GestureDetector(
            onTap: _fetchDatabases,
            child: Obx(
              () => controller.isFetchingDb.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : AppAssetImage(
                      assetPath: AppImage.arrowDown,
                      height: 20,
                      width: 20,
                      fallback: const Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Always gives the tap a visible result — advance, load the list, or say
  /// what is missing. See the Next button for why this can't be a no-op.
  Future<void> _handleNextPressed() async {
    if (auth.selectedDatabase.value.isNotEmpty) {
      controller.goToCredentialsStep();
      return;
    }

    if (auth.databases.isEmpty) {
      // The list is usually fetched when the address is entered, but a
      // pre-filled or pasted address can leave it empty. Fetch it here so the
      // button does the obvious thing instead of nothing.
      await _fetchDatabases();
      if (auth.databases.length == 1) {
        // Only one choice — pick it rather than making the user open a menu.
        auth.selectedDatabase.value = auth.databases.first;
        controller.goToCredentialsStep();
        return;
      }
    }

    if (auth.databases.isEmpty) {
      AppSnackbar.warning(
        'Server',
        controller.urlError.value.isNotEmpty
            ? controller.urlError.value
            : 'Enter your server address to load its databases.',
      );
      return;
    }
    AppSnackbar.info('Database', 'Choose a database to continue.');
  }

  Future<void> _fetchDatabases() async {
    final cleanHost = await controller.fetchDatabases();
    if (cleanHost.isNotEmpty) {
      controller.urlController.text = cleanHost;
    }
    if (controller.errorMessage.value.isNotEmpty) {
      controller.urlError.value = controller.errorMessage.value;
      controller.clearError();
    }
  }

  Widget _buildDatabaseDropdown() {
    return Obx(
      () => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCCCCCC)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        alignment: Alignment.center,
        child: DropdownButtonHideUnderline(
          child: AppDropdownButton<String>(
            isDense: true,
            value: auth.selectedDatabase.value.isEmpty
                ? null
                : auth.selectedDatabase.value,
            hint: Row(
              children: [
                AppAssetImage(
                  assetPath: AppIcon.database,
                  width: 18,
                  height: 18,
                  color: Colors.black,
                  fallback: const Icon(Icons.storage_outlined, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.selectDB,
                  style: AppTextStyles.style(
                    fontSize: 14,
                    color: const Color(0xFFCCCCCC),
                  ),
                ),
              ],
            ),
            icon: AppAssetImage(
              assetPath: AppImage.arrowDown,
              width: 20,
              height: 20,
              fallback: const Icon(Icons.keyboard_arrow_down, size: 20),
            ),
            isExpanded: true,
            items: auth.databases
                .map(
                  (db) => AppDropdownStyle.item(
                    value: db,
                    child: Text(
                      db,
                      style: AppTextStyles.style(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) auth.selectedDatabase.value = value;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildLoginModeToggle(),
        const SizedBox(height: 16),
        Obx(
          () => _buildTextFieldContainer(
            child: Row(
              children: [
                AppAssetImage(
                  assetPath: AppIcon.user,
                  height: 18,
                  width: 18,
                  fallback: const Icon(Icons.person_outline, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller.usernameController,
                    textInputAction: TextInputAction.next,
                    keyboardType: controller.isEmployeeMode
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    style: AppTextStyles.style(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: controller.isEmployeeMode
                          ? 'Login Email'
                          : 'Enter Username',
                      hintStyle: AppTextStyles.style(
                        fontSize: 14,
                        color: const Color(0xFFCCCCCC),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      filled: false,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Obx(
          () => controller.usernameError.value.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      controller.usernameError.value,
                      style: AppTextStyles.style(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        Obx(
          () => _buildTextFieldContainer(
            child: Row(
              children: [
                AppAssetImage(
                  assetPath: AppIcon.password,
                  height: 18,
                  width: 18,
                  fallback: const Icon(Icons.lock_outline, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller.passwordController,
                    obscureText: controller.obscurePassword.value,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => controller.handleLogin(),
                    style: AppTextStyles.style(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter Password',
                      hintStyle: AppTextStyles.style(
                        fontSize: 14,
                        color: const Color(0xFFCCCCCC),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      filled: false,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => controller.obscurePassword.value =
                      !controller.obscurePassword.value,
                  child: Icon(
                    controller.obscurePassword.value
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
        Obx(
          () => controller.passwordError.value.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      controller.passwordError.value,
                      style: AppTextStyles.style(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Obx(
          () => controller.errorMessage.value.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
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
                            controller.errorMessage.value,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: ForgotPasswordSheet.show,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot password?',
              style: AppTextStyles.style(
                fontSize: 13,
                color: AppColors.authbuttoncolor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Obx(
          () => _buildPrimaryButton(
            onPressed: auth.isLoading.value ? null : controller.handleLogin,
            child: auth.isLoading.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primaryButtonForeground,
                    ),
                  )
                : Text(
                    AppStrings.login,
                    style: AppTextStyles.button.copyWith(
                      color: _primaryButtonForeground,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginModeToggle() {
    return Obx(() {
      // "Restrict Mobile App Access" disabled on the server → plain user
      // sign-in only: no Employee tab, no mode switcher at all.
      if (!controller.employeeLoginEnabled.value) {
        return const SizedBox.shrink();
      }
      final mode = controller.loginMode.value;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _modeTab('User', AccountModel.modeUser, mode),
            _modeTab('Employee', AccountModel.modeEmployee, mode),
          ],
        ),
      );
    });
  }

  Widget _modeTab(String label, String value, String current) {
    final selected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setLoginMode(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.blueGradient : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.style(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  static const Color _primaryButtonBackground = Color(0xFFD9D9D9);
  static const Color _primaryButtonForeground = Color(0xFF2B2A2A);

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryButtonBackground,
        disabledBackgroundColor: _primaryButtonBackground,
        foregroundColor: _primaryButtonForeground,
        disabledForegroundColor: _primaryButtonForeground,
        elevation: 0,
        minimumSize: const Size(double.infinity, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: child,
    );
  }

  Widget _buildTextFieldContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.center,
      child: child,
    );
  }

  ImageProvider? _decodeAvatar(String? base64Image) {
    if (base64Image == null || base64Image.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(base64Image));
    } catch (_) {
      return null;
    }
  }
}
