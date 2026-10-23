import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/assets.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/translation_service.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/auth_repository.dart';

class MyProfileView extends StatefulWidget {
  const MyProfileView({super.key});

  @override
  State<MyProfileView> createState() => _MyProfileViewState();
}

class _MyProfileViewState extends State<MyProfileView> {
  final AuthRepository _authRepository = Get.find<AuthRepository>();
  final NetworkService _network = Get.find<NetworkService>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUpdatingLanguage = false;
  String _error = '';
  Map<String, dynamic> _profile = <String, dynamic>{};
  final _controllers = <String, TextEditingController>{};
  List<Map<String, String>> _languageOptions = const <Map<String, String>>[];
  List<Map<String, String>> _timezoneOptions = const <Map<String, String>>[];
  List<Map<String, dynamic>> _warehouseOptions = const <Map<String, dynamic>>[];
  String? _selectedLanguageCode;
  String? _selectedTimeZone;
  int? _selectedWarehouseId;


  @override
  void initState() {
    super.initState();
    _controllers['position'] = TextEditingController();
    _controllers['work_mobile'] = TextEditingController();
    _controllers['work_phone'] = TextEditingController();
    _controllers['work_email'] = TextEditingController();
    _controllers['work_location'] = TextEditingController();
    _controllers['manager'] = TextEditingController();
    _controllers['coach'] = TextEditingController();
    _controllers['email_signature'] = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    final data = await _authRepository.fetchMyProfileDetails();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (data == null) {
        _error = AppStrings.profileLoadError;
      } else {
        _profile = data;
        _languageOptions = (data['language_options'] as List?)
                ?.map((e) => Map<String, String>.from(e as Map))
                .toList() ??
            const <Map<String, String>>[];
        _timezoneOptions = (data['time_zone_options'] as List?)
                ?.map((e) => Map<String, String>.from(e as Map))
                .toList() ??
            const <Map<String, String>>[];
        _warehouseOptions = (data['warehouse_options'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const <Map<String, dynamic>>[];
        _controllers['position']!.text = _profile['position']?.toString() ?? '';
        _controllers['work_mobile']!.text = _profile['work_mobile']?.toString() ?? '';
        _controllers['work_phone']!.text = _profile['work_phone']?.toString() ?? '';
        _controllers['work_email']!.text = _profile['work_email']?.toString() ?? '';
        _controllers['work_location']!.text = _profile['work_location']?.toString() ?? '';
        _controllers['manager']!.text = _profile['manager']?.toString() ?? '';
        _controllers['coach']!.text = _profile['coach']?.toString() ?? '';
        _controllers['email_signature']!.text = _profile['email_signature']?.toString() ?? '';
        _selectedLanguageCode = _profile['language_code']?.toString();
        _selectedTimeZone = _profile['time_zone']?.toString();
        _selectedWarehouseId = _profile['default_warehouse_id'] is int
            ? _profile['default_warehouse_id'] as int
            : int.tryParse('${_profile['default_warehouse_id']}');
      }
    });
  }

  String _txt(String key) {
    final v = _profile[key];
    if (v == null) return '-';
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final username = _txt('name');
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFFCFCFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 20,
        backgroundColor: AppColors.primary,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error.isNotEmpty
                ? _buildError()
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader(username)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        sliver: SliverToBoxAdapter(
                          child: _buildProfileForm(),
                        ),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveProfile,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              label: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(AppStrings.profileSave),
              icon: _isSaving ? null : const Icon(Icons.save_outlined),
            )
          : null,
    );
  }

  Widget _buildHeader(String username) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = _profile['image_url']?.toString() ?? '';
    final sessionId = _network.sessionId ?? '';
    return Column(
      children: [
        Container(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Image.asset(AppImage.back, height: 25, width: 25,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  username,
                  style: AppTextStyles.h1.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 21,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<Uint8List?>(
          future: imageUrl.isNotEmpty ? _fetchImageBytes(imageUrl, sessionId) : Future.value(null),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return CircleAvatar(
                radius: 50,
                backgroundColor: isDark ? AppColors.darkSurface3 : const Color(0xFFE0E0E0),
                child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              );
            }
            if (snap.hasData && snap.data != null) {
              return CircleAvatar(radius: 50, backgroundImage: MemoryImage(snap.data!));
            }
            return CircleAvatar(
              radius: 50,
              backgroundColor: isDark ? AppColors.darkSurface3 : const Color(0xFFE0E0E0),
              child: Icon(Icons.person, size: 50,
                  color: isDark ? AppColors.darkTextSecondary : Colors.grey),
            );
          },
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildProfileForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFEAEAEA),
        ),
      ),
      child: Column(
        children: [
          _textField(AppStrings.profileFieldPosition, _controllers['position']!),
          _textField(AppStrings.profileFieldWorkMobile, _controllers['work_mobile']!),
          _textField(AppStrings.profileFieldWorkPhone, _controllers['work_phone']!),
          _textField(AppStrings.profileFieldWorkEmail, _controllers['work_email']!),
          _textField(AppStrings.profileFieldWorkLocation, _controllers['work_location']!),
          _textField(AppStrings.profileFieldManager, _controllers['manager']!),
          _textField(AppStrings.profileFieldCoach, _controllers['coach']!),
          _languageFieldWithUpdate(),
          _dropdownField<String>(
            AppStrings.profileFieldTimeZone,
            _selectedTimeZone,
            _timezoneOptions
                .map((o) => DropdownMenuItem<String>(
                      value: o['value'],
                      child: Text(o['label'] ?? o['value'] ?? ''),
                    ))
                .toList(),
            (v) => setState(() => _selectedTimeZone = v),
          ),
          _textField(AppStrings.profileFieldEmailSig, _controllers['email_signature']!, multiline: true),
          _dropdownField<int>(
            AppStrings.profileFieldWarehouse,
            _selectedWarehouseId,
            _warehouseOptions
                .map((o) => DropdownMenuItem<int>(
                      value: o['id'] as int?,
                      child: Text(o['name']?.toString() ?? ''),
                    ))
                .toList(),
            (v) => setState(() => _selectedWarehouseId = v),
          ),
        ],
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller, {bool multiline = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: multiline ? 4 : 1,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF6F6F6),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: multiline ? 12 : 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownField<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    void Function(T?) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            initialValue: items.any((e) => e.value == value) ? value : null,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF6F6F6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
            dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final payload = <String, dynamic>{
      ..._profile,
      'position': _controllers['position']!.text.trim(),
      'work_mobile': _controllers['work_mobile']!.text.trim(),
      'work_phone': _controllers['work_phone']!.text.trim(),
      'work_email': _controllers['work_email']!.text.trim(),
      'work_location': _controllers['work_location']!.text.trim(),
      'manager': _controllers['manager']!.text.trim(),
      'coach': _controllers['coach']!.text.trim(),
      'email_signature': _controllers['email_signature']!.text.trim(),
      'language_code': _selectedLanguageCode,
      'time_zone': _selectedTimeZone,
      'default_warehouse_id': _selectedWarehouseId,
    };
    final ok = await _authRepository.updateMyProfileDetails(profile: payload);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? AppStrings.profileUpdateSuccess : AppStrings.profileUpdateFailed),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
    // REPLACE WITH:
    // Language change fires regardless of ok — res.users write succeeds
    // even when hr.employee fields fail
    final newLangCode = _selectedLanguageCode ?? 'en_US';
    final langName = _languageOptions
        .firstWhere(
          (l) => l['value'] == newLangCode,
      orElse: () => <String, String>{'label': newLangCode},
    )['label'] ??
        newLangCode;
    if (Get.isRegistered<TranslationService>()) {
      // Never force-refresh on profile save — use cache if available.
      // Silent background refresh (in TranslationService.onInit) handles
      // picking up Odoo translation changes automatically on next app start.
      unawaited(TranslationService.to.changeLanguage(
        newLangCode,
        langName,
        forceRefresh: false,
      ));
    }

    // Don't reload profile after language change — it causes extra lag
    // and the profile data hasn't changed meaningfully.
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 44),
            const SizedBox(height: 10),
            Text(_error, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child:  Text(AppStrings.profileRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageFieldWithUpdate() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnglish = (_selectedLanguageCode ?? 'en_US').toLowerCase().startsWith('en');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.profileFieldLanguage,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Language dropdown ──
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _languageOptions.any((o) => o['value'] == _selectedLanguageCode)
                      ? _selectedLanguageCode
                      : null,
                  items: _languageOptions
                      .map((o) => DropdownMenuItem<String>(
                    value: o['value'],
                    child: Text(o['label'] ?? o['value'] ?? ''),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedLanguageCode = v),
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF6F6F6),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),

              // ── Update button (hidden for English) ──
              if (!isEnglish) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingLanguage ? null : _onUpdateLanguagePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.7),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: _isUpdatingLanguage
                        ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(
                      _isUpdatingLanguage ? '...' : 'Update',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onUpdateLanguagePressed() async {
    final langCode = _selectedLanguageCode;
    if (langCode == null || langCode.toLowerCase().startsWith('en')) return;

    final langName = _languageOptions
        .firstWhere(
          (l) => l['value'] == langCode,
      orElse: () => <String, String>{'label': langCode},
    )['label'] ??
        langCode;

    setState(() => _isUpdatingLanguage = true);
    try {
      await TranslationService.to.forceRefreshLanguage(langCode, langName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$langName updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingLanguage = false);
    }
  }
}

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
  } catch (_) {}
  return null;
}


