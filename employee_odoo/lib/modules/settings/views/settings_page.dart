import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../../data/services/location_tracking_service.dart';
import '../../attendance/utils/route_tracking_consent.dart';
import '../utils/biometric_helper.dart';
import '../widgets/biometric_status_dialog.dart';
import 'company_profile_page.dart';
import '../../../core/utils/responsive.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isBiometricEnabled = false;
  bool _isLoadingBiometric = true;
  bool _isRouteTrackingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await BiometricHelper.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _isBiometricEnabled = enabled;
      _isRouteTrackingEnabled = RouteTrackingConsent.isGranted;
      _isLoadingBiometric = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppMainAppBar(title: 'Settings'),
      body: ResponsiveBody(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Account', Icons.person_outline),
          const SizedBox(height: 12),
          _buildAccountCards(),
          const SizedBox(height: 24),
          _buildSectionHeader('Security', Icons.security_outlined),
          const SizedBox(height: 12),
          _buildSecurityCard(),
          const SizedBox(height: 12),
          _buildRouteTrackingCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('Help & Support', Icons.help_outline),
          const SizedBox(height: 12),
          _buildHelpSupportCards(),
          const SizedBox(height: 24),
          _buildSectionHeader('About', Icons.info_outline),
          const SizedBox(height: 12),
          _buildAboutCards(),
          const SizedBox(height: 24),
          _buildSectionHeader('Follow Us', Icons.share_outlined),
          const SizedBox(height: 12),
          _buildSocialMediaSection(),
          const SizedBox(height: 24),
          _buildAppVersion(),
        ],
      )),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.style(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF454545),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCards() {
    return _SettingsCard(
      children: [
        _buildMenuTile(
          icon: Icons.business_outlined,
          iconColor: AppColors.primary,
          title: 'Company Profile',
          subtitle: 'Manage your company details',
          onTap: () => Get.to(() => const CompanyProfilePage()),
        ),
        _buildDivider(),
        _buildMenuTile(
          icon: Icons.account_circle_outlined,
          iconColor: AppColors.primary,
          title: 'My Odoo Account',
          subtitle: 'View and edit your account details',
          onTap: () => _launchURL(
            'https://accounts.odoo.com/web/login?scope=userinfo&mode=login',
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return _SettingsCard(
      child: _isLoadingBiometric
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint, color: Colors.white, size: 24),
              ),
              title: Text(
                'Biometric Authentication',
                style: AppTextStyles.style(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _isBiometricEnabled
                      ? 'Enabled - Ask for biometrics on app start'
                      : 'Disabled',
                  style: AppTextStyles.style(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              trailing: Switch(
                value: _isBiometricEnabled,
                onChanged: _handleBiometricToggle,
                activeThumbColor: AppColors.white,
                activeTrackColor: AppColors.brandBlue,
              ),
            ),
    );
  }

  Widget _buildRouteTrackingCard() {
    return _SettingsCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppColors.brandOrange,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.route_outlined,
              color: Colors.white, size: 24),
        ),
        title: Text(
          'Attendance Route Tracking',
          style: AppTextStyles.style(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _isRouteTrackingEnabled
                ? 'On - Records your route while checked in'
                : 'Off - No location is recorded',
            style: AppTextStyles.style(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: Switch(
          value: _isRouteTrackingEnabled,
          onChanged: _handleRouteTrackingToggle,
          activeThumbColor: AppColors.white,
          activeTrackColor: AppColors.brandBlue,
        ),
      ),
    );
  }

  Future<void> _handleRouteTrackingToggle(bool enabled) async {
    if (enabled) {
      // Play's Prominent Disclosure policy requires the disclosure on every
      // path that opts the user in to location collection — not just the
      // check-in flow. Opting in from here has to show it too.
      if (!await RouteTrackingConsent.requestConsent()) {
        if (mounted) setState(() => _isRouteTrackingEnabled = false);
        return;
      }
    }
    await RouteTrackingConsent.setGranted(enabled);
    if (!enabled) {
      // Turning it off stops any active tracking immediately.
      await LocationTrackingService.instance.stop();
    }
    if (mounted) {
      setState(() => _isRouteTrackingEnabled = enabled);
    }
  }

  Future<void> _handleBiometricToggle(bool enabled) async {
    if (enabled) {
      final canEnable = await BiometricHelper.canEnableBiometric();
      if (!canEnable) {
        _showBiometricNotAvailableDialog();
        return;
      }

      final authenticated = await BiometricHelper.authenticate(
        reason: 'Authenticate to enable biometric login',
      );

      if (authenticated == true) {
        setState(() => _isBiometricEnabled = true);
        await BiometricHelper.setBiometricEnabled(true);
        if (!mounted) return;
        await BiometricStatusDialog.show(context, enabled: true);
      } else if (authenticated == false) {
        if (!mounted) return;
        _showErrorDialog('Authentication failed. Please try again.');
      } else {
        _showBiometricNotAvailableDialog();
      }
    } else {
      final authenticated = await BiometricHelper.authenticate(
        reason: 'Authenticate to disable biometric login',
      );

      if (authenticated == true) {
        setState(() => _isBiometricEnabled = false);
        await BiometricHelper.setBiometricEnabled(false);
        if (!mounted) return;
        await BiometricStatusDialog.show(context, enabled: false);
      } else if (authenticated == false) {
        if (!mounted) return;
        _showErrorDialog('Authentication failed. Cannot disable biometric.');
      }
    }
  }

  void _showBiometricNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_outlined, color: Colors.orange),
            SizedBox(width: 12),
            Text('Biometric Not Available'),
          ],
        ),
        content: const Text(
          'Biometric authentication is not available on this device or no biometrics are enrolled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSupportCards() {
    return _SettingsCard(
      children: [
        _buildMenuTile(
          icon: Icons.menu_book_outlined,
          iconColor: Colors.blue,
          title: 'Documentation',
          subtitle: 'Browse app documentation',
          onTap: () => _launchURL('https://www.odoo.com/documentation/18.0/'),
        ),
        _buildDivider(),
        _buildMenuTile(
          icon: Icons.support_agent_outlined,
          iconColor: Colors.orange,
          title: 'Support',
          subtitle: 'Get help from our support team',
          onTap: () => _launchURL('https://www.odoo.com/pricing#hosting=on_premise'),
        ),
      ],
    );
  }

  Widget _buildAboutCards() {
    return _SettingsCard(
      children: [
        _buildMenuTile(
          icon: Icons.language_outlined,
          iconColor: AppColors.primary,
          title: 'Visit Website',
          subtitle: 'www.koderxpert.com',
          onTap: () => _launchURL('https://koderxpert.com/'),
        ),
        _buildDivider(),
        _buildMenuTile(
          icon: Icons.contact_mail_outlined,
          iconColor: AppColors.primary,
          title: 'Contact Us',
          subtitle: 'Get in touch with us',
          onTap: () => _launchURL('https://koderxpert.com/contactus'),
        ),
      ],
    );
  }

  Widget _buildSocialMediaSection() {
    final links = [
      (AppIcon.facebook, 'Facebook', 'https://www.facebook.com/koderxpert/', Icons.facebook),
      (AppIcon.twitter, 'Twitter', 'https://x.com/KoderXpert', Icons.alternate_email),
      (AppIcon.instagram, 'Instagram', 'https://www.instagram.com/koderxpert/', Icons.camera_alt_outlined),
      (AppIcon.linkedin, 'LinkedIn', 'https://www.linkedin.com/company/koderxpert', Icons.work_outline),
      (AppIcon.youtube, 'YouTube', 'https://www.youtube.com/@koderxperttech', Icons.play_circle_outline),
    ];

    return _SettingsCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Connect with us on social media',
              style: AppTextStyles.style(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: links.map((link) {
                return _SocialIcon(
                  assetPath: link.$1,
                  fallback: link.$4,
                  label: link.$2,
                  onTap: () => _launchURL(link.$3),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
      title: Text(
        title,
        style: AppTextStyles.style(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: AppTextStyles.style(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border);
  }

  Widget _buildAppVersion() {
    return Center(
      child: Text(
        'Copyright © Koderxpert Technologies LLP.\n${AppConstants.appName} v${AppConstants.appVersion}',
        textAlign: TextAlign.center,
        style: AppTextStyles.style(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        _showErrorDialog('Could not open the link');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Failed to open the link');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: AppTextStyles.style(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({this.child, this.children});

  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: child ?? Column(children: children ?? []),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({
    required this.assetPath,
    required this.fallback,
    required this.label,
    required this.onTap,
  });

  final String assetPath;
  final IconData fallback;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  fallback,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.style(fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
