import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/responsive.dart';

class CompanyProfilePage extends StatefulWidget {
  const CompanyProfilePage({super.key});

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  final _auth = Get.find<AuthController>();
  bool _loading = true;
  List<Map<String, dynamic>> _companyDetails = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      if (_auth.odooClient == null) return;

      final ids = _auth.selectedCompanyIds;
      if (ids.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final result = await _auth.odooClient!.callKw({
        'model': 'res.company',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', 'in', ids],
          ],
          'fields': ['name', 'email', 'phone', 'website', 'street', 'city', 'country_id'],
          'order': 'name asc',
        },
      });

      if (result is List) {
        setState(() {
          _companyDetails = result.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading company profile: $e');
      setState(() => _loading = false);
    }
  }

  String _safeString(dynamic value) {
    if (value == null || value == false) return '';
    if (value is List && value.length > 1) return value[1].toString();
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppMainAppBar(title: 'Company Profile'),
      body: ResponsiveBody(child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _companyDetails.isEmpty
              ? Center(
                  child: Text(
                    'No company selected',
                    style: AppTextStyles.style(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _companyDetails.length,
                  itemBuilder: (context, index) {
                    final company = _companyDetails[index];
                    return _CompanyCard(
                      name: _safeString(company['name']),
                      email: _safeString(company['email']),
                      phone: _safeString(company['phone']),
                      website: _safeString(company['website']),
                      address: [
                        _safeString(company['street']),
                        _safeString(company['city']),
                        _safeString(company['country_id']),
                      ].where((s) => s.isNotEmpty).join(', '),
                    );
                  },
                )),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.website,
    required this.address,
  });

  final String name;
  final String email;
  final String phone;
  final String website;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.brandBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.style(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (email.isNotEmpty) _InfoRow(icon: Icons.email_outlined, label: email),
          if (phone.isNotEmpty) _InfoRow(icon: Icons.phone_outlined, label: phone),
          if (website.isNotEmpty) _InfoRow(icon: Icons.language_outlined, label: website),
          if (address.isNotEmpty) _InfoRow(icon: Icons.location_on_outlined, label: address),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.style(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
