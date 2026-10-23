import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/local/auth_storage.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../../core/utils/responsive.dart';

class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  final AuthController _authController = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();

  bool _isEditing = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _mobileController;
  late TextEditingController _websiteController;
  late TextEditingController _jobTitleController;

  Map<String, dynamic>? _userDetails;
  String? _companyName;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  static const _navy = AppColors.brandBlue;

  bool _jobPositionEditable = true;
  bool _workPhoneEditable = true;
  Timer? _hintSnackTimer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _mobileController = TextEditingController();
    _websiteController = TextEditingController();
    _jobTitleController = TextEditingController();
    _loadUserDetails();
  }

  @override
  void dispose() {
    _hintSnackTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _websiteController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  String _safeString(dynamic value) {
    if (value == null || value == false) return '';
    return value.toString();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Photo Source',
              style: AppTextStyles.style(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Camera'),
              subtitle: const Text('Take a new photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Gallery'),
              subtitle: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to pick image'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _loadUserDetails() async {
    try {
      final userId = _authController.activeAccount.value?.userId;
      if (userId == null) throw Exception('No active user');

      final result = await _authController.odooClient!.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', userId],
          ],
          [
            'name',
            'email',
            'phone',
            'mobile',
            'website',
            'image_1920',
            'partner_id',
            'company_id',
            'function',
            'employee_id',
          ]
        ],
        'kwargs': {},
      });

      if (result == null || result.isEmpty) return;

      final userDetails = Map<String, dynamic>.from(result[0] as Map);

      bool jobEditable = true;
      bool phoneEditable = true;

      final employeeField = userDetails['employee_id'];
      if (employeeField is List && employeeField.isNotEmpty) {
        final employeeId = employeeField[0] as int;

        // Read work_phone on its own — if this specific field is
        // group-restricted, only this read fails, not everything.
        try {
          final phoneResult = await _authController.odooClient!.callKw({
            'model': 'hr.employee',
            'method': 'search_read',
            'args': [
              [
                ['id', '=', employeeId],
              ],
              ['work_phone'],
            ],
            'kwargs': {},
          });
          if (phoneResult is List && phoneResult.isNotEmpty) {
            final workPhone = (phoneResult.first as Map)['work_phone'];
            if (workPhone is String && workPhone.isNotEmpty) {
              userDetails['phone'] = workPhone;
            }
          }
        } catch (e) {
          debugPrint('No access to work_phone: $e');
          phoneEditable = false;
        }

        // Read job_id on its own for the same reason.
        try {
          final jobResult = await _authController.odooClient!.callKw({
            'model': 'hr.employee',
            'method': 'search_read',
            'args': [
              [
                ['id', '=', employeeId],
              ],
              ['job_id'],
            ],
            'kwargs': {},
          });
          if (jobResult is List && jobResult.isNotEmpty) {
            final jobId = (jobResult.first as Map)['job_id'];
            if (jobId is List && jobId.length > 1) {
              userDetails['function'] = jobId[1];
            }
          }
        } catch (e) {
          debugPrint('No access to job_id: $e');
          jobEditable = false;
        }
      }

      if (!mounted) return;

      setState(() {
        _userDetails = userDetails;
        _jobPositionEditable = jobEditable;
        _workPhoneEditable = phoneEditable;
        if (_userDetails!['image_1920'] == false) {
          _userDetails!['image_1920'] = null;
        }
        if (_userDetails!['company_id'] != null && _userDetails!['company_id'] is List) {
          _companyName = _userDetails!['company_id'][1] as String?;
        }
        _nameController.text = _safeString(_userDetails!['name']);
        _emailController.text = _safeString(_userDetails!['email']);
        _phoneController.text = _safeString(_userDetails!['phone']);
        _mobileController.text = _safeString(_userDetails!['mobile']);
        _websiteController.text = _safeString(_userDetails!['website']);
        _jobTitleController.text = _safeString(_userDetails!['function']);
      });
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', 'Failed to load user details', snackPosition: SnackPosition.BOTTOM);
    }
  }

  int? get _partnerId {
    if (_userDetails == null) return null;
    final partner = _userDetails!['partner_id'];
    if (partner is List && partner.isNotEmpty) return partner[0] as int;
    if (partner is int) return partner;
    return null;
  }

  String _odooErrorMessage(Object error) {
    final text = error.toString();
    if (error is OdooException) {
      return text.replaceFirst('OdooException: ', '').trim();
    }
    return text.replaceAll('Exception: ', '').trim();
  }

  Future<void> _saveUserDetails() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userDetails == null) {
      _showSnack('Profile not loaded. Please try again.', isError: true);
      return;
    }

    final partnerId = _partnerId;
    if (partnerId == null) {
      _showSnack('Could not resolve your contact record.', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: _navy),
      ),
    );

    String? savedImageBase64;

    try {
      final partnerData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'website': _websiteController.text.trim(),
        'function': _jobTitleController.text.trim(),
      };

      if (_selectedImage != null) {
        final imageBytes = await _selectedImage!.readAsBytes();
        savedImageBase64 = base64Encode(imageBytes);
        partnerData['image_1920'] = savedImageBase64;
      }

      // Avatar + contact fields live on res.partner (employees can write own partner).
      await _authController.odooClient!.callKw({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId],
          partnerData,
        ],
        'kwargs': {},
      });

      // Keep res.users in sync for name/email (skip image — stored on partner).
      final userId = _authController.activeAccount.value?.userId;
      if (userId != null) {
        await _authController.odooClient!.callKw({
          'model': 'res.users',
          'method': 'write',
          'args': [
            [userId],
            {
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
            },
          ],
          'kwargs': {},
        });
      }

      // NOTE: no try/catch swallow here anymore — if this fails (e.g. an
      // access-rights error on hr.employee), it must surface to the user
      // via the catch block below instead of failing silently.
      await _syncLinkedEmployee(
        phone: _phoneController.text.trim(),
        jobTitleText: _jobTitleController.text.trim(),
        imageBase64: savedImageBase64,
      );

      await _loadUserDetails();

      final sanitizedImage = OdooImage.sanitize(
        savedImageBase64 ?? _userDetails?['image_1920'],
      );

      final updatedAccount = _authController.activeAccount.value?.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        image1920: sanitizedImage,
      );

      if (updatedAccount != null) {
        _authController.activeAccount.value = updatedAccount;
        await AuthStorage.saveAccount(updatedAccount);
      }

      if (Get.isRegistered<HomeController>()) {
        final home = Get.find<HomeController>();
        home.applyAccountProfileToDisplay();
        await home.refreshProfile();
      }

      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _selectedImage = null;
      });

      _showSnack('Profile updated successfully');
    } catch (e) {
      debugPrint('Profile save error: $e');
      if (!mounted) return;
      _showSnack(
        _selectedImage != null
            ? 'Failed to update profile picture: ${_odooErrorMessage(e)}'
            : 'Failed to update profile: ${_odooErrorMessage(e)}',
        isError: true,
      );
    } finally {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _syncLinkedEmployee({
    required String phone,
    required String jobTitleText,
    String? imageBase64,
  }) async {
    final userId = _authController.activeAccount.value?.userId;
    if (userId == null) return;

    final users = await _authController.odooClient!.callKw({
      'model': 'res.users',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', userId],
        ],
      ],
      'kwargs': {
        'fields': ['employee_id'],
        'limit': 1,
      },
    });

    if (users is! List || users.isEmpty) return;
    final user = Map<String, dynamic>.from(users.first as Map);
    final employeeField = user['employee_id'];
    if (employeeField is! List || employeeField.isEmpty) return;

    final employeeId = employeeField[0] as int;
    final employeeData = <String, dynamic>{};

    // Only attempt work_phone if we've confirmed access. The UI already
    // disables the field, but this guards against stale state.
    if (_workPhoneEditable && phone.isNotEmpty) {
      employeeData['work_phone'] = phone;
    }

    if (_jobPositionEditable && jobTitleText.isNotEmpty) {
      try {
        final jobs = await _authController.odooClient!.callKw({
          'model': 'hr.job',
          'method': 'search_read',
          'args': [
            [
              ['name', '=', jobTitleText],
            ],
          ],
          'kwargs': {
            'fields': ['id'],
            'limit': 1,
          },
        });

        if (jobs is List && jobs.isNotEmpty) {
          final jobId = (jobs.first as Map)['id'] as int;
          employeeData['job_id'] = jobId;
        }
      } catch (e) {
        debugPrint('Skipping job_id update (no hr.job access): $e');
      }
    }

    if (imageBase64 != null) {
      employeeData['image_1920'] = imageBase64;
    }

    if (employeeData.isEmpty) return;

    await _authController.odooClient!.callKw({
      'model': 'hr.employee',
      'method': 'write',
      'args': [
        [employeeId],
        employeeData,
      ],
      'kwargs': {},
    });
  }


  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(color: Colors.white),
        title: Text(
          'Profile Details',
          style: AppTextStyles.style(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          // Employee-mode sessions run on a shared account, so profile editing
          // is disabled — it would edit the wrong record.
          if (!_isEditing && !Get.find<AuthController>().isEmployeeMode)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _selectedImage = null;
                });
                _loadUserDetails();
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.style(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: _saveUserDetails,
              child: Text(
                'Save',
                style: AppTextStyles.style(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      body: ResponsiveBody(child: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildPersonalInfoForm(),
          ],
        ),
      )),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 60,
        bottom: 32,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          _buildProfileImage(),
          const SizedBox(height: 20),
          Text(
            _safeString(_userDetails?['name']).isNotEmpty
                ? _safeString(_userDetails?['name'])
                : 'Unknown User',
            style: AppTextStyles.style(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (_safeString(_userDetails?['function']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _safeString(_userDetails?['function']),
                style: AppTextStyles.style(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          if (_companyName != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  _companyName!,
                  style: AppTextStyles.style(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    final imageData = _userDetails?['image_1920'];
    ImageProvider? imageProvider;

    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (imageData != null &&
        imageData != false &&
        imageData is String &&
        imageData.isNotEmpty) {
      final sanitized = OdooImage.sanitize(imageData);
      if (sanitized != null) {
        try {
          imageProvider = MemoryImage(base64Decode(sanitized));
        } catch (_) {}
      }
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 62,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 58,
              backgroundColor: _navy.withValues(alpha: 0.1),
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Text(
                      (_userDetails?['name'] ?? 'U').toString()[0].toUpperCase(),
                      style: AppTextStyles.style(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _navy, width: 3),
                ),
                child: const Icon(Icons.camera_alt, color: _navy, size: 20),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalInfoForm() {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: AppTextStyles.style(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF454545),
              ),
            ),
            const SizedBox(height: 20),
            _buildFormField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              enabled: _isEditing,
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!GetUtils.isEmail(v.trim())) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildFormField(
              controller: _phoneController,
              label: 'Phone',
              icon: Icons.phone_outlined,
              enabled: _isEditing && _workPhoneEditable,
              keyboardType: TextInputType.phone,
              disabledHint: _workPhoneEditable
                  ? 'Tap edit to modify your profile'
                  : "You don't have permission to change Phone. Contact your administrator.",
            ),
            const SizedBox(height: 16),
            _buildFormField(
              controller: _mobileController,
              label: 'Mobile',
              icon: Icons.smartphone_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              controller: _websiteController,
              label: 'Website',
              icon: Icons.language_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              controller: _jobTitleController,
              label: 'Job Title',
              icon: Icons.work_outline,
              enabled: _isEditing && _jobPositionEditable,
              disabledHint: _jobPositionEditable
                  ? 'Tap edit to modify your profile'
                  : "You don't have permission to change Job Position. Contact your administrator.",
            ),
            const SizedBox(height: 16),
            _buildFormField(
              controller: TextEditingController(text: _companyName ?? 'N/A'),
              label: 'Company',
              icon: Icons.business_outlined,
              enabled: false,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String disabledHint = 'Tap edit to modify your profile',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.style(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (!enabled) {
              _showHintSnack(disabledHint);
            }
          },
          child: AbsorbPointer(
            absorbing: !enabled,
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              validator: validator,
              style: AppTextStyles.style(fontSize: 15),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: enabled ? _navy : Colors.grey[400],
                ),
                hintText: 'Enter $label',
                filled: true,
                fillColor: enabled ? AppColors.inputFill : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _navy, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showHintSnack(String message) {
    if (!mounted) return;

    _hintSnackTimer?.cancel();

    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar(); // instant removal, no wait for prior animation
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _hintSnackTimer = Timer(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  Future<void> _checkJobPositionAccess() async {
    try {
      final canRead = await _authController.odooClient!.callKw({
        'model': 'hr.job',
        'method': 'check_access_rights',
        'args': ['read', false], // raise_exception = false -> returns bool
        'kwargs': {},
      });
      if (!mounted) return;
      setState(() {
        _jobPositionEditable = canRead == true;
      });
    } catch (e) {
      // If even the check fails, be conservative and disable editing.
      if (!mounted) return;
      setState(() => _jobPositionEditable = false);
    }
  }
}
