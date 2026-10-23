import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../../data/models/employee_directory_record.dart';
import '../../../data/repositories/employee_directory_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/widgets/section_title.dart';
import '../../../core/utils/responsive.dart';

class EmployeeDirectoryDetailView extends StatefulWidget {
  const EmployeeDirectoryDetailView({super.key});

  @override
  State<EmployeeDirectoryDetailView> createState() => _EmployeeDirectoryDetailViewState();
}

class _EmployeeDirectoryDetailViewState extends State<EmployeeDirectoryDetailView> {
  EmployeeDirectoryRecord? _employee;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = Get.arguments as int?;
    if (id == null) {
      setState(() { _notFound = true; _loading = false; });
      return;
    }
    final client = Get.find<AuthController>().odooClient;
    final repo = EmployeeDirectoryRepository(client!);
    final employee = await repo.fetchById(id);
    setState(() {
      _employee = employee;
      _notFound = employee == null;
      _loading = false;
    });
  }

  Future<void> _launch(String scheme, String value) async {
    final uri = Uri.parse('$scheme:$value');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar('Unavailable', 'No app found to handle this action', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppMainAppBar(title: 'Employee'),
      body: ResponsiveBody(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandBlue))
          : _notFound
          ? _buildNotFound()
          : _buildDetail(_employee!)),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              'This employee could not be found.',
              style: AppTextStyles.style(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(EmployeeDirectoryRecord e) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _HeaderCard(employee: e),
        const SizedBox(height: 24),
        SectionTitle(title: 'Contact Information', accentColor: AppColors.brandOrange),
        const SizedBox(height: 14),
        if (e.mobilePhone != null)
          _ContactRow(
            icon: Icons.smartphone_rounded,
            iconColor: AppColors.brandBlue,
            label: 'Mobile',
            value: e.mobilePhone!,
            onCall: () => _launch('tel', e.mobilePhone!),
            onMessage: () => _launch('smsto', e.mobilePhone!),
          ),
        if (e.workPhone != null)
          _ContactRow(
            icon: Icons.call_rounded,
            iconColor: AppColors.brandBlueLight,
            label: 'Work Phone',
            value: e.workPhone!,
            onCall: () => _launch('tel', e.workPhone!),
          ),
        if (e.workEmail != null)
          _ContactRow(
            icon: Icons.email_rounded,
            iconColor: AppColors.brandOrange,
            label: 'Email',
            value: e.workEmail!,
            onEmail: () => _launch('mailto', e.workEmail!),
          ),
        if (!e.hasContactInfo)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            ),
            child: Column(
              children: [
                Icon(Icons.contact_page_outlined, size: 34, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  'No contact info available for this employee.',
                  style: AppTextStyles.style(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.employee});

  final EmployeeDirectoryRecord employee;

  @override
  Widget build(BuildContext context) {
    final e = employee;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildAvatar(e),
              if (e.presence != EmployeePresence.unknown)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: e.presence == EmployeePresence.checkedIn
                          ? const Color(0xFF22C55E)
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            e.name,
            style: AppTextStyles.style(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.white),
            textAlign: TextAlign.center,
          ),
          if (e.jobTitle != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                e.jobTitle!,
                style: AppTextStyles.style(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.white),
              ),
            ),
          ],
          if (e.departmentName != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_outlined, size: 14, color: Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Text(
                  e.departmentName!,
                  style: AppTextStyles.style(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ],
          if (e.presence != EmployeePresence.unknown) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: e.presence == EmployeePresence.checkedIn
                          ? const Color(0xFF22C55E)
                          : Colors.white.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.presence == EmployeePresence.checkedIn ? 'Checked In' : 'Checked Out',
                    style: AppTextStyles.style(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.white),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(EmployeeDirectoryRecord e) {
    final safe = OdooImage.sanitize(e.avatarBase64);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: safe != null
          ? CircleAvatar(radius: 48, backgroundColor: AppColors.white, backgroundImage: MemoryImage(base64Decode(safe)))
          : CircleAvatar(
        radius: 48,
        backgroundColor: AppColors.white,
        child: Text(
          e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
          style: AppTextStyles.style(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.brandBlue),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onCall,
    this.onMessage,
    this.onEmail,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onEmail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.style(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.style(fontSize: 13.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onCall != null) _ActionButton(icon: Icons.call_rounded, onTap: onCall!),
          if (onMessage != null) ...[
            const SizedBox(width: 6),
            _ActionButton(icon: Icons.chat_bubble_rounded, onTap: onMessage!),
          ],
          if (onEmail != null) _ActionButton(icon: Icons.send_rounded, onTap: onEmail!),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandBlue.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 16, color: AppColors.brandBlue),
        ),
      ),
    );
  }
}