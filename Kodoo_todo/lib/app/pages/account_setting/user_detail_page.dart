import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/navigation_helper.dart';
import '../../controllers/login_controller.dart';
import '../../core/assets.dart';

class UserProfileDetailPage extends StatefulWidget {
  const UserProfileDetailPage({super.key});

  @override
  State<UserProfileDetailPage> createState() => _UserProfileDetailPageState();
}

class _UserProfileDetailPageState extends State<UserProfileDetailPage> {
  final AuthController _authController = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();

  bool _isEditing = false;
  final bool _isLoading = false;

  // Controllers for form fields
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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _websiteController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  /// ✅ Helper to safely convert any value to String
  String _safeString(dynamic value) {
    if (value == null || value == false) {
      return '';
    }
    return value.toString();
  }

  Future<void> _pickImage() async {
    // Show dialog to choose camera or gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            SizedBox(height: 20),

            // Title
            Text(
              'Select Photo Source',
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            SizedBox(height: 20),

            // Camera Option
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFF1F5786).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.camera_alt, color: Color(0xFF1F5786), size: 24),
              ),
              title: Text(
                'Camera',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Take a new photo',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),

            Divider(height: 1),

            // Gallery Option
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library, color: Colors.green, size: 24),
              ),
              title: Text(
                'Gallery',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Choose from library',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),

            SizedBox(height: 16),

            // Cancel button
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  color: Colors.grey[700],
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            SizedBox(height: 10),
          ],
        ),
      ),
    );

    // If user cancelled, return
    if (source == null) return;

    // Pick image from selected source (camera or gallery)
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source, // ✅ Use the selected source
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        print('✅ Image selected from ${source == ImageSource.camera ? "camera" : "gallery"}');
      }
    } catch (e) {
      print("❌ Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to pick image"),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
    });
  }


  Future<void> _loadUserDetails() async {
    try {
      final userId = _authController.activeAccount.value?.userId;
      if (userId == null) throw Exception("No active user");

      // Fetch detailed user information
      final result = await _authController.odooClient!.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [['id', '=', userId]],
          [
            'name',
            'email',
            'phone',
            'mobile',
            'website',
            'image_1920',
            'partner_id',
            'company_id',
            'function', // Job title
          ]
        ],
        'kwargs': {},
      });

      if (result != null && result.isNotEmpty) {
        setState(() {
          _userDetails = result[0] as Map<String, dynamic>;

          // Handle false values
          if (_userDetails!['image_1920'] == false) {
            _userDetails!['image_1920'] = null;
          }

          // Get company name
          if (_userDetails!['company_id'] != null && _userDetails!['company_id'] is List) {
            _companyName = _userDetails!['company_id'][1] as String?;
          }

          // Populate form fields
          _nameController.text = _safeString(_userDetails!['name']);
          _emailController.text = _safeString(_userDetails!['email']);
          _phoneController.text = _safeString(_userDetails!['phone']);
          _mobileController.text = _safeString(_userDetails!['mobile']);
          _websiteController.text = _safeString(_userDetails!['website']);
          _jobTitleController.text = _safeString(_userDetails!['function']);
        });
      }
    } catch (e) {
      print("❌ Error loading user details: $e");

      NavigationHelper.showSnackbar(
        title: 'Error',
        message: 'Failed to load user details',
        position: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }
  Future<void> _saveUserDetails() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(
                    color: Color(0xFF6C5B7B),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final userId = _authController.activeAccount.value?.userId;
      if (userId == null) throw Exception("No active user");

      // Get partner_id (required for updating contact info)
      final partnerId = _userDetails!['partner_id'] is List
          ? _userDetails!['partner_id'][0]
          : _userDetails!['partner_id'];

      // Update user data
      // Prepare user data update
      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'function': _jobTitleController.text.trim(),
      };

      // ✅ Add image if selected
      if (_selectedImage != null) {
        final imageBytes = await _selectedImage!.readAsBytes();
        final base64Image = base64Encode(imageBytes);
        userData['image_1920'] = base64Image;
      }

      // Update user data
      await _authController.odooClient!.callKw({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [userId],
          userData,
        ],
        'kwargs': {},
      });

      // Update partner data (for phone, mobile, website)
      if (partnerId != null) {
        await _authController.odooClient!.callKw({
          'model': 'res.partner',
          'method': 'write',
          'args': [
            [partnerId],
            {
              'phone': _phoneController.text.trim(),
              'mobile': _mobileController.text.trim(),
              'website': _websiteController.text.trim(),
            }
          ],
          'kwargs': {},
        });
      }

      // Refresh user details
      await _loadUserDetails();

      // Update active account
      final updatedAccount = _authController.activeAccount.value?.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
      );

      if (updatedAccount != null) {
        _authController.activeAccount.value = updatedAccount;
      }

      setState(() {
        _isEditing = false;
        _selectedImage = null; // ✅ Clear selected image after save
      });

      // ✅ Close loading dialog
      Navigator.of(context).pop();

      // ✅ Show success snackbar from bottom
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Profile updated successfully",
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      print("❌ Error saving user details: $e");

      // ✅ Close loading dialog
      Navigator.of(context).pop();

      // ✅ Show error snackbar from bottom
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Failed to update profile",
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset(AppIcon.back, color: Colors.white,height: 26,width: 26,),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Profile Details",
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: Image.asset(AppIcon.edit, color: Colors.white,height: 25,width: 25,),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: "Edit Profile",
            ),
          if (_isEditing)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _selectedImage = null;
                });
                _loadUserDetails();
              },
              child: Text(
                "Cancel",
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _saveUserDetails,
              child: Text(
                "Save",
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Image Section
            _buildProfileHeader(),

            const SizedBox(height: 24),

            // Personal Information Form
            _buildPersonalInfoForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 60, // 🆕 Space for AppBar
        bottom: 32,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F5786),
            const Color(0xFFF06022),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Profile Image
          _buildProfileImage(),

          const SizedBox(height: 20),

          // User Name
          Text(
            _safeString(_userDetails?['name']) != ''
                ? _safeString(_userDetails?['name'])
                : 'Unknown User',
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Job Title
          if (_userDetails?['function'] != null &&
              _userDetails!['function'] != false &&
              _userDetails!['function'].toString().isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _userDetails!['function'].toString(),
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),

          // Company Name
          if (_companyName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(AppIcon.company, color: Colors.white70, height: 16,width: 16,),
                  SizedBox(width: 6),
                  Text(
                    _companyName!,
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    final imageData = _userDetails?['image_1920'];
    ImageProvider? imageProvider;

    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (imageData != null && imageData != false && imageData is String && imageData.isNotEmpty) {
      try {
        final imageBytes = base64Decode(imageData);
        imageProvider = MemoryImage(imageBytes);
      } catch (e) {
        print("❌ Error decoding profile image: $e");
      }
    }

    return Stack(
      children: [
        // Profile Image with shadow
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 62,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 58,
              backgroundColor: Color(0xFF1F5786).withOpacity(0.1),
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Text(
                (_userDetails?['name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F5786),
                ),
              )
                  : null,
            ),
          ),
        ),

        // Edit button
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Color(0xFF1F5786), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: PopupMenuButton<String>(
                color: Colors.white,
                icon: const Icon(
                  Icons.camera_alt,
                  color: Color(0xFF1F5786),
                  size: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'pick') {
                    _pickImage();
                  } else if (value == 'remove') {
                    _removeImage();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'pick',
                    child: Row(
                      children: [
                        Icon(Icons.photo_library, size: 20, color: Color(0xFF1F5786)),
                        SizedBox(width: 12),
                        Text(
                          "Choose Photo",
                          style: TextStyle(fontFamily: 'NunitoSans'),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedImage != null || imageProvider != null)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text(
                            "Remove Photo",
                            style: TextStyle(
                              color: Colors.red,
                              fontFamily: 'NunitoSans',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
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

            // Section Header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(0xFF1F5786),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 10),

                Text(
                  "Personal Information",
                  style: TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff2B2A2A),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Full Name
            _buildFormField(
              controller: _nameController,
              label: "Full Name",
              icon: Icons.person_outline,
              enabled: _isEditing,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Email
            _buildFormField(
              controller: _emailController,
              label: "Email",
              icon: Icons.email_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!GetUtils.isEmail(value.trim())) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Phone
            _buildFormField(
              controller: _phoneController,
              label: "Phone",
              icon: Icons.phone_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 16),

            // Mobile
            _buildFormField(
              controller: _mobileController,
              label: "Mobile",
              icon: Icons.smartphone_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 16),

            // Website
            _buildFormField(
              controller: _websiteController,
              label: "Website",
              icon: Icons.language_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 16),

            // Job Title
            _buildFormField(
              controller: _jobTitleController,
              label: "Job Title",
              icon: Icons.work_outline,
              enabled: _isEditing,
            ),

            const SizedBox(height: 16),

            // Company (Read-only)
            _buildFormField(
              controller: TextEditingController(text: _companyName ?? 'N/A'),
              label: "Company",
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            // 🆕 Show snackbar if field is disabled
            if (!enabled) {
              _showEditModeRequiredSnackbar();
            }
          },
          child: AbsorbPointer(
            absorbing: !enabled, // 🆕 Block interaction when disabled
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              validator: validator,
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 15,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: enabled ? Color(0xFF1F5786) : Colors.grey[400],
                  size: 22,
                ),
                hintText: 'Enter $label',
                hintStyle: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 15,
                  color: Colors.grey[400],
                ),
                filled: true,
                fillColor: enabled ? Color(0xFFF1F5F9) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF1F5786), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }


  void _showEditModeRequiredSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Please enable edit mode to modify your profile",
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF1F5786),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Enable',
          textColor: Colors.white,
          onPressed: () {
            setState(() => _isEditing = true);
          },
        ),
      ),
    );
  }

}