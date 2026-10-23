import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/assets.dart';
import '../../widgets/custom_app_bar.dart';
import 'biometric_helper.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isBiometricEnabled = false;
  bool _isLoadingBiometric = true;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _isLoadingBiometric = false;
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: "Settings",
        backgroundColor: Colors.grey[50],
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _buildSectionHeader("Account", Icons.person_outline),
          const SizedBox(height: 12),
          _buildAccountCards(),

          const SizedBox(height: 24),

          // Security Section
          _buildSectionHeader("Security", Icons.security_outlined),
          const SizedBox(height: 12),
          _buildSecurityCard(),

          const SizedBox(height: 24),

          // Help & Support Section
          _buildSectionHeader("Help & Support", Icons.help_outline),
          const SizedBox(height: 12),
          _buildHelpSupportCards(),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader("About", Icons.info_outline),
          const SizedBox(height: 12),
          _buildAboutCards(),

          const SizedBox(height: 24),

          // Follow Us Section
          _buildSectionHeader("Follow Us", Icons.share_outlined),
          const SizedBox(height: 12),
          _buildSocialMediaSection(),

          const SizedBox(height: 24),

          // App Version
          _buildAppVersion(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF6C5B7B),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey[700],
            letterSpacing: 0.5,

          ),
        ),
      ],
    );
  }

  Widget _buildAccountCards() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDivider(),
          _buildMenuTile(
            iconWidget: Image.asset(AppIcon.myaccount),
            iconColor: const Color(0xFF6C5B7B),
            title: "My Odoo Account",
            subtitle: "View and edit your account details",
            onTap: () {
              _launchURL('https://accounts.odoo.com/web/login?scope=userinfo&mode=login&login=&redirect=%2Foauth2%2Fauth%2F%3Fresponse_type%3Dtoken%26client_id%3Dab6392bb-2c13-11f0-8b68-bc2411df3c5b%26state%3D%257B%2522d%2522%253A%2B%2522koderxpert%2522%252C%2B%2522u%2522%253A%2B%2522https%253A%252F%252Fkoderxpert.com%2522%257D%26scope%3Duserinfo');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoadingBiometric
          ? const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6C5B7B),
          ),
        ),
      )
          : ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child:  Image.asset(
            AppIcon.authentication,
            color: Colors.black,
            height: 24,
            width: 24,
          ),
        ),
        title: const Text(
          "Biometric Authentication",
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _isBiometricEnabled
                ? "Enabled - Ask for biometrics on app start"
                : "Disabled",
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
        trailing: Switch(
          value: _isBiometricEnabled,
          onChanged: _handleBiometricToggle,
          activeThumbColor: Color(0xff1F5786),
          inactiveTrackColor: Color(0xff1F5786),
          inactiveThumbColor: Colors.black,
          trackOutlineColor: WidgetStateProperty.all(Colors.white),
          trackOutlineWidth: WidgetStateProperty.all(2),
        ),
      ),
    );
  }

// Replace your existing _handleBiometricToggle method with this enhanced version:

  Future<void> _handleBiometricToggle(bool enabled) async {
    if (enabled) {
      // User wants to enable biometric
      // First check if device supports it
      final bool canEnable = await BiometricHelper.canEnableBiometric();

      if (!canEnable) {
        _showBiometricNotAvailableDialog();
        return;
      }

      // Authenticate to confirm
      final bool? authenticated = await BiometricHelper.authenticate(
        reason: 'Authenticate to enable biometric login',
      );

      if (authenticated == true) {
        // Authentication successful, enable biometric
        setState(() {
          _isBiometricEnabled = true;
        });
        await BiometricHelper.setBiometricEnabled(true);

        if (!mounted) return;
        _showSuccessDialog(
          "Biometric Enabled",
          "Biometric authentication has been enabled. You'll be asked to authenticate when opening the app.",
        );
      } else if (authenticated == false) {
        // Authentication failed
        if (!mounted) return;
        _showErrorDialog("Authentication failed. Please try again.");
      } else {
        // Device doesn't support or no biometrics enrolled
        _showBiometricNotAvailableDialog();
      }
    } else {
      // User wants to disable biometric
      // Authenticate before disabling for security
      final bool? authenticated = await BiometricHelper.authenticate(
        reason: 'Authenticate to disable biometric login',
      );

      if (authenticated == true) {
        setState(() {
          _isBiometricEnabled = false;
        });
        await BiometricHelper.setBiometricEnabled(false);

        if (!mounted) return;
        _showSuccessDialog(
          "Biometric Disabled",
          "Biometric authentication has been disabled.",
        );
      } else if (authenticated == false) {
        if (!mounted) return;
        _showErrorDialog("Authentication failed. Cannot disable biometric.");
      }
    }
  }

// Add this helper method to show biometric not available dialog:

  void _showBiometricNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_outlined,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text("Biometric Not Available"),
          ],
        ),
        content: const Text(
          "Biometric authentication is not available on this device or no biometrics are enrolled.\n\nPlease:\n• Enable fingerprint or face recognition in your device settings\n• Enroll at least one fingerprint or face",
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            fontFamily: 'NunitoSans',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(
                fontFamily: 'NunitoSans',
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Add this helper method to show success dialog:

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 15,
            fontFamily: 'NunitoSans',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(
                fontFamily: 'NunitoSans',
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSupportCards()   {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuTile(
            iconWidget: Image.asset(AppIcon.documentation),
            iconColor: Colors.blue,
            title: "Documentation",
            subtitle: "Browse app documentation",
            onTap: () {
              _launchURL('https://www.odoo.com/documentation/18.0/');
            },
          ),
          _buildDivider(),
          _buildMenuTile(
            iconWidget: Image.asset(AppIcon.support),
            iconColor: Colors.orange,
            title: "Support",
            subtitle: "Get help from our support team",
            onTap: () {
              _launchURL('https://www.odoo.com/pricing#hosting=on_premise');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCards() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuTile(
            iconWidget: Image.asset(AppIcon.visitwebsite),
            iconColor: const Color(0xFF6C5B7B),
            title: "Visit Website",
            subtitle: "www.koderxpert.com",
            onTap: () {
              _launchURL('https://koderxpert.com/');
            },
          ),
          _buildDivider(),
          _buildMenuTile(
            iconWidget: Image.asset(AppIcon.contactus),
            iconColor: const Color(0xFF6C5B7B),
            title: "Contact Us",
            subtitle: "Get in touch with us",
            onTap: () {
              _launchURL('https://koderxpert.com/contactus');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Connect with us on social media",
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialIcon(
                icon: Image.asset(
                  AppIcon.facebook,
                  width: 24,
                  height: 24,
                ),
                color: const Color(0xFF1877F2),
                label: "Facebook",
                onTap: () {
                  _launchURL('https://www.facebook.com/koderxpert/');
                },
              ),

              _buildSocialIcon(
                icon: Image.asset(
                  AppIcon.twitter,
                  width: 24,
                  height: 24,
                ),
                color: const Color(0xFF25D366),
                label: "Twitter",
                onTap: () {
                  _launchURL('https://x.com/KoderXpert');
                },
              ),
              _buildSocialIcon(
                icon: Image.asset(
                  AppIcon.instagram,
                  width: 24,
                  height: 24,
                ),
                color: const Color(0xFFE4405F),
                label: "Instagram",
                onTap: () {
                  _launchURL('https://www.instagram.com/koderxpert/');
                },
              ),
              _buildSocialIcon(
                icon: Image.asset(
                  AppIcon.linkedin,
                  width: 24,
                  height: 24,
                ),
                color: const Color(0xFF0A66C2),
                label: "LinkedIn",
                onTap: () {
                  _launchURL('https://www.linkedin.com/company/koderxpert');
                },
              ),
              _buildSocialIcon(
                icon: Image.asset(
                  AppIcon.youtube,
                  width: 24,
                  height: 24,
                ),
                color: const Color(0xFF0A66C2),
                label: "YouTube",
                onTap: () {
                  _launchURL('https://www.youtube.com/@koderxperttech');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildSocialIcon({
    required Widget icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: icon,
          ),
          const SizedBox(height: 6),
          Text(label,
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 12,
            color: Colors.grey[600],
          ),
          ),
        ],
      ),
    );
  }


  Widget _buildMenuTile({
    required Widget iconWidget,
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
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          width: 24,
          height: 24,
          child: iconWidget,
        ),

      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'NunitoSans',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey[400],
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey[200],
    );
  }

  Widget _buildAppVersion() {
    return Center(
      child: Column(
        children: [
          Text(
            "Copyright © Koderxpert Technologies LLP.",
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }


  // Helper method to launch URLs
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        _showErrorDialog('Could not open the link');
      }
    } catch (e) {
      print("❌ Error launching URL: $e");
      if (!mounted) return;
      _showErrorDialog('Failed to open the link');
    }
  }

// Helper method to show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text("Error"),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}