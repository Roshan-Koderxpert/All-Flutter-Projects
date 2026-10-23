import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/responsive.dart';

class AddAccountPage extends StatefulWidget {
  const AddAccountPage({super.key});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final AuthController _authController = Get.find<AuthController>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginNewAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final activeAccount = _authController.activeAccount.value;
      if (activeAccount == null) {
        throw Exception('No active session found');
      }

      final username = _usernameController.text.trim();
      final navigatedToTwoFactor = await _authController.addAccount(
        url: activeAccount.url,
        database: activeAccount.database,
        username: username,
        password: _passwordController.text,
      );

      if (!navigatedToTwoFactor && mounted) {
        Get.snackbar(
          'Account',
          'Switched to $username',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900,
        );
        Get.back<void>();
      }
    } on OdooException catch (e) {
      _showError(_mapError(e));
    } catch (e) {
      _showError(_mapError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _mapError(Object e) {
    var errorMessage = e.toString().replaceAll('Exception: ', '');
    if (errorMessage.contains('already active')) {
      return 'This account is already active';
    }
    if (errorMessage.contains('Please enter password')) {
      return 'Please enter password';
    }
    if (errorMessage.contains('INVALID_CREDENTIALS') ||
        errorMessage.contains('Invalid username or password') ||
        errorMessage.contains('401') ||
        errorMessage.contains('Access Denied') ||
        errorMessage.contains('authentication failed') ||
        errorMessage.contains('Authentication failed') ||
        errorMessage.contains('wrong login/password') ||
        errorMessage.contains('Login failed')) {
      return 'Incorrect username or password';
    }
    if (errorMessage.contains('CONNECTION_TIMEOUT')) {
      return 'Connection timeout. Please try again.';
    }
    if (errorMessage.contains('Connection') ||
        errorMessage.contains('SocketException') ||
        errorMessage.contains('Network') ||
        errorMessage.contains('TimeoutException')) {
      return 'Connection error. Check your network.';
    }
    if (errorMessage.contains('No active session')) {
      return 'No active session. Please login first.';
    }
    return errorMessage;
  }

  @override
  Widget build(BuildContext context)   {
    return Scaffold(
      appBar: const AppMainAppBar(title: 'Add New Account'),
      body: ResponsiveBody(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Obx(() {
                  final active = _authController.activeAccount.value;
                  return Text(
                    'Adding account to database: ${active?.database ?? '-'}\n'
                    'URL: ${active?.url ?? '-'}',
                    style: AppTextStyles.style(fontSize: 13),
                  );
                }),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Username / Email',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter username'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isLoading) _loginNewAccount();
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please enter password' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _loginNewAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Add Account',
                        style: AppTextStyles.style(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
