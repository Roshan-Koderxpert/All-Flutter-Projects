import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/asset_icon.dart';
import '../../../core/utils/odoo_image.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_controller.dart';
// import '../widgets/account_switcher.dart'; // temporarily disabled, see Accounts section below
import '../widgets/company_selector.dart';
import '../widgets/profile_section_header.dart';
import '../../messaging/views/messaging_main_page.dart';
import '../../settings/views/settings_page.dart';
import 'user_detail_page.dart';

class ProfileTabView extends GetView<AuthController> {
  const ProfileTabView({super.key});

  @override
  Widget build(BuildContext context) {
    HomeController? home;
    if (Get.isRegistered<HomeController>()) {
      home = Get.find<HomeController>();
    }

    return Obx(() {
      final account = controller.activeAccount.value;
      home?.avatarBase64.value;
      final name =
          home?.displayName ?? account?.name ?? controller.userName.value;
      final email = account?.email ?? account?.username ?? '';
      final image =
          home?.profileAvatarBase64 ?? OdooImage.sanitize(account?.image1920);

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileHeaderCard(
              name: name,
              email: email,
              database: account?.database ?? controller.selectedDatabase.value,
              imageBase64: image,
              onTap: () => Get.to(() => const UserDetailPage()),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const SizedBox(height: 16),
                  _QuickActionsGrid(
                    onMessages: () => Get.to(() => const MessagingMainPage()),
                    onSettings: () => Get.to(() => const SettingsPage()),
                    onHelp: () => _launchHelp(),
                  ),
                  const SizedBox(height: 20),
                  const ProfileSectionHeader(title: 'Company Selection'),
                  const SizedBox(height: 12),
                  const ProfileCard(child: CompanySelector()),
                  const SizedBox(height: 20),
                  // Multiple-login / saved-accounts switcher — temporarily
                  // disabled per product request. Uncomment to re-enable.
                  // const ProfileSectionHeader(title: 'Accounts'),
                  // const SizedBox(height: 12),
                  // const ProfileCard(
                  //   padding: EdgeInsets.fromLTRB(12, 12, 12, 16),
                  //   child: AccountSwitcher(),
                  // ),
                  // const SizedBox(height: 20),
                  _LogoutCard(
                    savedAccountCount: controller.savedAccounts.length,
                    onLogout: () => _confirmLogout(context),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _launchHelp() async {
    final uri = Uri.parse('https://www.odoo.com/help');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'Error',
          'Could not open help page',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (_) {
      Get.snackbar(
        'Error',
        'Failed to open help page',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final logoutAll = controller.savedAccounts.length > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const AssetIcon(
                assetPath: AppIcon.logout,
                fallback: Icons.logout_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                logoutAll ? 'Logout all devices' : 'Logout',
                style: AppTextStyles.style(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          logoutAll
              ? 'Sign out from all ${controller.savedAccounts.length} saved accounts on this device? You can sign in again from the remembered accounts list.'
              : 'Are you sure you want to logout from your current account?',
          style: AppTextStyles.style(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.style(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              logoutAll ? 'Logout all' : 'Logout',
              style: AppTextStyles.style(
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (logoutAll) {
        await controller.logoutAll();
      } else {
        await controller.logout();
      }
    }
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.name,
    required this.email,
    required this.database,
    required this.imageBase64,
    required this.onTap,
  });

  final String name;
  final String email;
  final String database;
  final String? imageBase64;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _ProfileAvatar(name: name, imageBase64: imageBase64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.style(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.storage_rounded,
                              size: 14,
                              color: AppColors.white,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                database.isNotEmpty ? database : 'No Database',
                                style: AppTextStyles.style(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: AppColors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                email,
                                style: AppTextStyles.style(
                                  fontSize: 13,
                                  color: AppColors.white.withValues(alpha: 0.95),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, required this.imageBase64});

  final String name;
  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    final safe = OdooImage.sanitize(imageBase64);
    if (safe != null) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 32,
          backgroundImage: MemoryImage(base64Decode(safe)),
          backgroundColor: AppColors.white,
        ),
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.white,
        child: Text(
          initial,
          style: AppTextStyles.style(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onMessages,
    required this.onSettings,
    required this.onHelp,
  });

  final VoidCallback onMessages;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        assetPath: AppIcon.message,
        fallback: Icons.chat_bubble_outline_rounded,
        label: 'Messages',
        color: const Color(0xFF6C5B7B),
        onTap: onMessages,
      ),
      _QuickAction(
        assetPath: AppIcon.setting,
        fallback: Icons.settings_outlined,
        label: 'Settings',
        color: const Color(0xFFE74C3C),
        onTap: onSettings,
      ),
      _QuickAction(
        assetPath: AppIcon.help,
        fallback: Icons.help_outline_rounded,
        label: 'Help',
        color: const Color(0xFF00A09D),
        onTap: onHelp,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) => _QuickActionCard(action: actions[index]),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.assetPath,
    required this.fallback,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String assetPath;
  final IconData fallback;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: action.color,
                  shape: BoxShape.circle,
                ),
                child: AssetIcon(
                  assetPath: action.assetPath,
                  fallback: action.fallback,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                action.label,
                style: AppTextStyles.style(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({
    required this.savedAccountCount,
    required this.onLogout,
  });

  final int savedAccountCount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final logoutAll = savedAccountCount > 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const AssetIcon(
                    assetPath: AppIcon.logout,
                    fallback: Icons.logout_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        logoutAll ? 'Logout all devices' : 'Logout',
                        style: AppTextStyles.style(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        logoutAll
                            ? 'Sign out from all saved accounts on this device'
                            : 'Sign out from your account',
                        style: AppTextStyles.style(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // const AssetIcon(
                //   assetPath: AppIcon.logout,
                //   fallback: Icons.logout_rounded,
                //   size: 20,
                //   color: AppColors.error,
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
