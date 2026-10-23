import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/asset_icon.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../data/models/account_model.dart';
import '../../auth/controllers/auth_controller.dart';

class AccountSwitcher extends GetView<AuthController> {
  const AccountSwitcher({super.key});

  @override
  Widget build(BuildContext context) { 
    return Obx(() {
      final accounts = controller.savedAccounts;
      final activeId = controller.activeAccount.value?.id;

      if (accounts.isEmpty) {
        return Text(
          'No saved accounts',
          style: AppTextStyles.style(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        );
      }

      return Column(
        children: [
          ...accounts.map((account) {
            final isActive = account.id == activeId;
            final canSwitch = !isActive && account.canSilentSignIn;
            return _AccountRow(
              account: account,
              isActive: isActive,
              isSignedOut: !isActive && !account.canSilentSignIn,
              onSwitch: isActive
                  ? null
                  : canSwitch
                      ? () async {
                          try {
                            final navigatedToTwoFactor =
                                await controller.switchAccount(account);
                            if (!navigatedToTwoFactor) {
                              Get.snackbar(
                                'Account',
                                'Switched to ${account.username}',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            }
                          } catch (e) {
                            Get.snackbar(
                              'Account',
                              e.toString().replaceFirst('Exception: ', ''),
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red.shade100,
                              colorText: Colors.red.shade900,
                            );
                          }
                        }
                      : () => controller.signInSavedAccount(account),
              onDelete: () => _confirmDelete(context, account),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.addAccount),
              icon: const AssetIcon(
                assetPath: AppIcon.addAccount,
                fallback: Icons.person_add_alt_1,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                'Add Another Account',
                style: AppTextStyles.style(
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _confirmDelete(BuildContext context, AccountModel account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove account?'),
        content: Text('Remove ${account.username} from saved accounts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.removeAccount(account.id);
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.isActive,
    required this.isSignedOut,
    required this.onSwitch,
    required this.onDelete,
  });

  final AccountModel account;
  final bool isActive;
  final bool isSignedOut;
  final VoidCallback? onSwitch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.brandBlue.withValues(alpha: 0.06)
            : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          _AccountAvatar(account: account),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name ?? account.username,
                        style: AppTextStyles.style(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Active',
                          style: AppTextStyles.style(
                            fontSize: 10,
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ] else if (isSignedOut) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Signed out',
                          style: AppTextStyles.style(
                            fontSize: 10,
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${account.database} • ${account.url}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.style(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onSwitch != null)
            TextButton(
              onPressed: onSwitch,
              child: Text(isSignedOut ? 'Sign in' : 'Switch'),
            ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onDelete,
            icon: const AssetIcon(
              assetPath: AppIcon.remove,
              fallback: Icons.delete_outline,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.account});

  final AccountModel account;

  @override
  Widget build(BuildContext context) {
    final safe = OdooImage.sanitize(account.image1920);
    if (safe != null) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: MemoryImage(base64Decode(safe)),
      );
    }
    final initial =
        (account.name ?? account.username).isNotEmpty
            ? (account.name ?? account.username)[0].toUpperCase()
            : 'U';
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.brandBlue,
      child: Text(
        initial,
        style: AppTextStyles.style(
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}
