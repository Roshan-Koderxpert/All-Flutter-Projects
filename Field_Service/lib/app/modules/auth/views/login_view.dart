import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/assets.dart';
import '../../../core/theme/text_styles.dart';
import '../controllers/auth_controller.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final AuthController controller = Get.find<AuthController>();

  final TextEditingController _urlController = TextEditingController();

  // ── These stay local (pure UI state) ──────────
  final RxBool _showLoginForm   = false.obs;
  final RxBool _obscurePassword = true.obs;
  final RxString _urlError      = ''.obs;
  final RxString _usernameError = ''.obs;
  final RxString _passwordError = ''.obs;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ── Step 1: fetch databases via controller ────
  Future<void> _fetchDatabases() async {
    final value = _urlController.text.trim();
    if (value.isEmpty) {
      _urlError.value = 'Please enter server URL';
      return;
    }
    _urlError.value = '';

    final cleanHost = await controller.fetchDatabases(value);
    if (cleanHost.isNotEmpty) {
      _urlController.text = cleanHost;
    }

    // Show any error that came back from the network
    if (controller.errorMessage.value.isNotEmpty) {
      _urlError.value = controller.errorMessage.value;
      controller.clearError();
    }
  }

  // ── Step 2: validate + login ──────────────────
  Future<void> _handleLogin() async {
    _usernameError.value = '';
    _passwordError.value = '';
    controller.clearError();

    if (controller.usernameController.text.trim().isEmpty) {
      _usernameError.value = 'Username is required';
    }
    if (controller.passwordController.text.trim().isEmpty) {
      _passwordError.value = 'Password is required';
    }
    if (_usernameError.value.isNotEmpty || _passwordError.value.isNotEmpty) {
      return;
    }

    await controller.login();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(20),
        child: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppImage.loginBg),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Must not exceed parent max height or BoxConstraints assert fails
              // (e.g. keyboard open → viewport smaller than full screen).
              final minScrollHeight = constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height * 0.85;
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: minScrollHeight,
                  ),
                  // Obx must wrap widgets that read .obs — not above LayoutBuilder
                  // (LayoutBuilder's builder runs later; GetX won't track those reads).
                  child: Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // ── Back button (only on step 2) ──────
                      SizedBox(
                        height: 52,
                        child: _showLoginForm.value
                            ? Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                top: 12, left: 12),
                            child: GestureDetector(
                              onTap: () =>
                              _showLoginForm.value = false,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color:
                                  Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 20),

                      // ── App logo ──────────────────────────
                      Center(
                        child: Image.asset(
                          AppImage.logo,
                          width: 200,
                          height: 70,
                        ),
                      ),
                      const SizedBox(height: 80),

                      // ── Login card ────────────────────────
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: 342,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 2,
                                spreadRadius: 0,
                                offset: Offset.zero,
                              ),
                            ],
                          ),
                          child: _buildCardContent(),
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Card content switcher ─────────────────────
  Widget _buildCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.signIn,
          textAlign: TextAlign.center,
          style: AppTextStyles.displayLarge,
        ),
        const SizedBox(height: 8),
        Text(
          _showLoginForm.value
              ? AppStrings.loginCredentialSubtitle
              : AppStrings.loginServerSubtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: 24),
        _showLoginForm.value ? _buildLoginForm() : _buildServerConfig(),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // STEP 1 — Server Configuration
  // ─────────────────────────────────────────────
  Widget _buildServerConfig() {
    return Column(
      children: [
        _buildServerUrlField(),
        Obx(() => _urlError.value.isNotEmpty
            ? Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _urlError.value,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
        )
            : const SizedBox.shrink()),
        const SizedBox(height: 20),

        _buildDatabaseDropdown(),
        const SizedBox(height: 20),

        // Next button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Obx(() => ElevatedButton(
            onPressed: controller.selectedDatabase.value.isEmpty
                ? null
                : () => _showLoginForm.value = true,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              AppStrings.next,
              style: AppTextStyles.button,
            ),
          )),
        ),
      ],
    );
  }

  Widget _buildServerUrlField() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Image.asset(AppImage.url, width: 18, height: 18,
              color: Colors.black),
          const SizedBox(width: 8),

          // Protocol dropdown — now uses controller.selectedProtocol
          Obx(() => DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              itemHeight: 50,
              value: controller.selectedProtocol.value,
              borderRadius: BorderRadius.circular(12),
              icon: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Image.asset(AppImage.arrow_down,
                    width: 20, height: 20),
              ),
              items: const ['http://', 'https://']
                  .map(
                    (protocol) => DropdownMenuItem<String>(
                  value: protocol,
                  child: Text(protocol,
                      style: const TextStyle(fontSize: 14)),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  controller.selectedProtocol.value = value;
                }
              },
            ),
          )),

          const SizedBox(width: 5),
          Container(height: 24, width: 1, color: const Color(0xFFDDDDDD)),
          const SizedBox(width: 8),

          // URL text field
          Expanded(
            child: TextField(
              controller: _urlController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _fetchDatabases(),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Enter Server Address',
                hintStyle: TextStyle(
                    fontSize: 14, color: Color(0xFFCCCCCC)),
                border: InputBorder.none,
                isDense: true,
                filled: false,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Fetch button — now uses controller.isFetchingDb
          GestureDetector(
            onTap: _fetchDatabases,
            child: Obx(() => controller.isFetchingDb.value
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
                : Image.asset(AppImage.arrow_down,
                height: 20, width: 20)),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseDropdown() {
    // Uses controller.databases and controller.selectedDatabase
    return Obx(() => Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          borderRadius: BorderRadius.circular(12),
          value: controller.selectedDatabase.value.isEmpty
              ? null
              : controller.selectedDatabase.value,
          hint: Row(
            children: [
              Image.asset(AppImage.database,
                  width: 18, height: 18, color: Colors.black),
              const SizedBox(width: 8),
              const Text(
                AppStrings.selectDB,
                style: TextStyle(
                    fontSize: 14, color: Color(0xFFCCCCCC)),
              ),
            ],
          ),
          icon: Image.asset(AppImage.arrow_down,
              width: 20, height: 20),
          isExpanded: true,
          items: controller.databases
              .map(
                (db) => DropdownMenuItem<String>(
              value: db,
              child: Text(db,
                  style: const TextStyle(fontSize: 14)),
            ),
          )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              controller.selectedDatabase.value = value;
            }
          },
        ),
      ),
    ));
  }

  // ─────────────────────────────────────────────
  // STEP 2 — Login Form
  // ─────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Column(
      children: [
        // Username
        _buildTextFieldContainer(
          child: Row(
            children: [
              Image.asset(AppImage.username, height: 18, width: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller.usernameController,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Enter Username',
                    hintStyle: TextStyle(
                        fontSize: 14, color: Color(0xFFCCCCCC)),
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
        if (_usernameError.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _usernameError.value,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 13),
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Password
        Obx(() => _buildTextFieldContainer(
          child: Row(
            children: [
              Image.asset(AppImage.password, height: 18, width: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller.passwordController,
                  obscureText: _obscurePassword.value,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Enter Password',
                    hintStyle: TextStyle(
                        fontSize: 14, color: Color(0xFFCCCCCC)),
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
                onTap: () =>
                _obscurePassword.value = !_obscurePassword.value,
                child: Icon(
                  _obscurePassword.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        )),
        if (_passwordError.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _passwordError.value,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 13),
              ),
            ),
          ),

        // API error banner from controller
        Obx(() => controller.errorMessage.value.isNotEmpty
            ? Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.error.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.errorMessage.value,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        )
            : const SizedBox.shrink()),

        const SizedBox(height: 20),

        // Login button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Obx(() => ElevatedButton(
            onPressed:
            controller.isLoading.value ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
              AppColors.primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: controller.isLoading.value
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Text(
              AppStrings.login,
              style: AppTextStyles.button,
            ),
          )),
        ),
      ],
    );
  }

  // ── Shared text field container ───────────────
  Widget _buildTextFieldContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: child,
    );
  }
}
