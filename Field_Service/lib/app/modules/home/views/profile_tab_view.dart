import 'dart:typed_data';
import 'dart:io';
import 'package:field_service/app/core/constants/assets.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/theme/text_styles.dart';
import 'my_profile_view.dart';
import '../controllers/home_controller.dart';
import '../controllers/profile_controller.dart';

class ProfileTabView extends GetView<ProfileController> {
  const ProfileTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Profile',
                  style: AppTextStyles.h1.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ── Avatar ──────────────────────────────────
            Obx(() {
              final url = controller.profileImageUrl.value;
              if (url.isEmpty) {
                return const CircleAvatar(
                  radius: 52,
                  backgroundColor: Color(0xFFE0E0E0),
                  child: Icon(Icons.person, size: 52, color: Colors.grey),
                );
              }
              final sessionId = Get.find<NetworkService>().sessionId ?? '';
              return FutureBuilder<Uint8List?>(
                future: _fetchImageBytes(url, sessionId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircleAvatar(
                      radius: 52,
                      backgroundColor: Color(0xFFE0E0E0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    );
                  }
                  if (snapshot.hasData && snapshot.data != null) {
                    return CircleAvatar(
                      radius: 52,
                      backgroundImage: MemoryImage(snapshot.data!),
                    );
                  }
                  return const CircleAvatar(
                    radius: 52,
                    backgroundColor: Color(0xFFE0E0E0),
                    child: Icon(Icons.person, size: 52, color: Colors.grey),
                  );
                },
              );
            }),
            const SizedBox(height: 14),

            // ── Name ────────────────────────────────────
            Obx(() => Text(
              controller.profileName.value.isEmpty
                  ? Get.find<HomeController>().username
                  : controller.profileName.value,
              style: AppTextStyles.h2.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            )),
            const SizedBox(height: 24),

            // ── Card ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ?AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── Companies ─────────────────────────
                  _SectionHeader(
                    icon: AppImage.companies,
                    label: 'Companies',
                  ),
                  Obx(() {
                    final list = controller.companies;
                    if (list.isEmpty) {
                      return _CheckItem(
                        id: -1,
                        label: Get.find<HomeController>().dbName.isEmpty ? 'My Company' : Get.find<HomeController>().dbName,
                        selectedIds: controller.draftSelectedCompanyIds,
                        onToggle: (_) {},
                      );
                    }
                    return Column(
                      children: list.map((c) {
                        final id = c['id'] as int;
                        final name = c['name']?.toString() ?? '';
                        return _CheckItem(
                          id: id,
                          label: name,
                          selectedIds: controller.draftSelectedCompanyIds,
                          onToggle: (checked) {
                            controller.toggleCompanySelection(id, checked);
                          },
                        );
                      }).toList(),
                    );
                  }),
                  Obx(() {
                    final applied = controller.selectedCompanyIds.toList()..sort();
                    final draft = controller.draftSelectedCompanyIds.toList()..sort();
                    final hasChanges = applied.join(',') != draft.join(',');
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: hasChanges
                                  ? controller.resetCompanySelectionDraft
                                  : null,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isDark ? AppColors.darkBorder : const Color(0xFFD0D0D0),
                                ),
                                foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                              child: Text('Reset',
                              style: TextStyle(
                                color: isDark ? AppColors.white :  Colors.black,
                              ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: hasChanges
                                  ? () async {
                                      final changed =
                                          await controller.confirmCompanySelection();
                                      if (!context.mounted) return;
                                      if (changed) {
                                        Get.find<HomeController>().selectTab(0);
                                      }
                                    }
                                  : null,
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                  (states) => states.contains(WidgetState.disabled)
                                      ? AppColors.primary.withValues(alpha: 0.55)
                                      : AppColors.primary,
                                ),
                                foregroundColor:
                                    WidgetStateProperty.all<Color>(Colors.white),
                                overlayColor: WidgetStateProperty.all<Color>(
                                  Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: const Text('Confirm'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),

                  // ── Documentation ─────────────────────
                  _MenuItem(
                    icon: AppImage.doc,
                    label: 'Documentation',
                    onTap: () => _launchURL('https://www.odoo.com/documentation/18.0/'),
                  ),

                  // ── Support ───────────────────────────
                  _MenuItem(
                    icon: AppImage.support,
                    label: 'Support',
                    onTap: () => _launchURL('https://www.odoo.com/pricing#hosting=on_premise'),
                  ),

                  // ── Dark Mode ─────────────────────────
                  _DarkModeItem(),

                  // ── My Profile ────────────────────────
                  _MenuItem(
                    icon:AppImage.myprofile,
                    label: 'My Profile',
                    onTap: () => Get.to(() => const MyProfileView()),
                  ),

                  // ── My Odoo.com account ───────────────
                  _MenuItem(
                    icon: AppImage.myodooaccount,
                    label: 'My Odoo.com account',
                    onTap: () => _launchURL('https://accounts.odoo.com/web/login?scope=userinfo&mode=login&login=&redirect=%2Foauth2%2Fauth%2F%3Fresponse_type%3Dtoken%26client_id%3Df742cdb8-3a30-11f1-8af7-acde48001122%26state%3D%257B%2522d%2522%253A%2B%2522test_field_serviecs%2522%252C%2B%2522u%2522%253A%2B%2522http%253A%252F%252F192.168.1.9%253A8069%2522%257D%26scope%3Duserinfo'),
                  ),

                  const SizedBox(height: 4),

                  // ── Logout ────────────────────────────
                  _LogoutItem(
                    onTap: () => _showLogoutDialog(context),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fetch image with session cookie ───────────────────────────────────────────
Future<Uint8List?> _fetchImageBytes(String url, String sessionId) async {
  try {
    final client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    final request = await client.getUrl(Uri.parse(url));
    if (sessionId.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, 'session_id=$sessionId');
    }
    final response = await request.close();
    if (response.statusCode == 200) {
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      client.close();
      return Uint8List.fromList(bytes);
    }
    client.close();
    return null;
  } catch (_) {
    return null;
  }
}

Future<void> _launchURL(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _showLogoutDialog(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surfaceColor = isDark ? const Color(0xFF1F1F1F) : Colors.white;
  final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
  final titleColor = isDark ? Colors.white : AppColors.textPrimary;
  final closeIconColor = isDark ? Colors.white70 : Colors.black87;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: closeIconColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to logout?',
                style: AppTextStyles.h2.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Get.find<HomeController>().logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Logout'),
                ),
              ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ── Section header row (Companies, etc.) ──────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPrimary : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _RedIconBox(icon: icon),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTextStyles.profileItemHeading.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Checkbox sub-item under Companies ─────────────────────────────────────────
class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.id,
    required this.label,
    required this.selectedIds,
    required this.onToggle,
  });

  final int id;
  final String label;
  final RxList<int> selectedIds;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final checked = selectedIds.contains(id);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: GestureDetector(
          onTap: () => onToggle(!checked),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: checked ? AppColors.primary : const Color(0xFFCCCCCC),
                    width: 1.8,
                  ),
                  borderRadius: BorderRadius.circular(5),
                  color: checked ? AppColors.primary : Colors.transparent,
                ),
                child: checked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.profileItemHeading.copyWith(
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Standard menu item row ────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
          color: isDark ? AppColors.darkPrimary : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _RedIconBox(icon: icon),
              const SizedBox(width: 14),
              Text(
                label,
              style: AppTextStyles.profileItemHeading.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dark mode toggle row ───────────────────────────────────────────────────────
class _DarkModeItem extends StatefulWidget {
  const _DarkModeItem();

  @override
  State<_DarkModeItem> createState() => _DarkModeItemState();
}

class _DarkModeItemState extends State<_DarkModeItem> {
  final ThemeService _themeService = Get.find<ThemeService>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPrimary : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _RedIconBox(icon: AppImage.darklightmode),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Dark Mode',
                style: AppTextStyles.profileItemHeading.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            Switch(
              value: isDark,
              onChanged: (v) => _themeService.setDark(v),
              activeThumbColor: isDark ? AppColors.primary : AppColors.white,
              activeTrackColor: isDark ? Colors.white : AppColors.textPrimary,
              inactiveThumbColor: isDark ? AppColors.darkTextSecondary : AppColors.white,
              inactiveTrackColor: isDark ? Colors.white : const Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logout row ────────────────────────────────────────────────────────────────
class _LogoutItem extends StatelessWidget {
  const _LogoutItem({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Image.asset(
                AppImage.logout,
                color: AppColors.primary,
                height: 25,
                width: 25,
              ),
              const SizedBox(width: 10),
              Text(
                'Logout',
                style: AppTextStyles.profileItemHeading.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Red circle icon box (shared) ──────────────────────────────────────────────
class _RedIconBox extends StatelessWidget {
  const _RedIconBox({required this.icon});
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Image.asset(icon, color: Colors.white),
      ),
    );
  }
}