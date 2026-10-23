import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../controllers/chatter_controller.dart';
import 'chat_thread_view.dart';
import '../../../core/utils/responsive.dart';

class NewChatPickerView extends StatefulWidget {
  const NewChatPickerView({super.key});

  @override
  State<NewChatPickerView> createState() => _NewChatPickerViewState();
}

class _NewChatPickerViewState extends State<NewChatPickerView> {
  final _controller = Get.find<ChatterController>();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  int? _startingChatForEmployeeId;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    setState(() => _loading = true);
    final results = await _controller.fetchEmployeesForNewChat(query);
    if (!mounted) return;
    setState(() {
      _employees = results;
      _loading = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(value));
  }

  bool _hasAccount(Map<String, dynamic> employee) {
    final userField = employee['user_id'];
    return userField is List && userField.isNotEmpty;
  }

  Future<void> _startChat(Map<String, dynamic> employee) async {
    final id = employee['id'] as int?;
    if (id == null || _startingChatForEmployeeId != null) return;

    if (!_hasAccount(employee)) {
      Get.snackbar('Unavailable', 'This employee doesn\'t have a login account to message',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _startingChatForEmployeeId = id);
    final channelId = await _controller.startChatWithEmployee(employee);
    if (!mounted) return;
    setState(() => _startingChatForEmployeeId = null);

    if (channelId == null) {
      Get.snackbar('Error', 'Could not start this chat, please try again', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final name = employee['name']?.toString() ?? 'Chat';
    // Replace the picker with the thread so back-navigation returns
    // straight to wherever the user came from, not through the picker.
    Get.off(() => ChatThreadView(channelId: channelId, title: name, imageBase64: employee['image_128'] as String?));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppMainAppBar(title: 'New Chat'),
      body: ResponsiveBody(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: AppColors.brandBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: AppTextStyles.style(fontSize: 13.5),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        hintText: 'Search by name, title, or department',
                        hintStyle: AppTextStyles.style(fontSize: 13, color: AppColors.textSecondary),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.brandBlue))
                : _employees.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline_rounded, size: 44, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No employees found', style: AppTextStyles.style(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: _employees.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final employee = _employees[index];
                final id = employee['id'] as int;
                final hasAccount = _hasAccount(employee);
                final isStarting = _startingChatForEmployeeId == id;
                return _EmployeeTile(
                  employee: employee,
                  hasAccount: hasAccount,
                  isStarting: isStarting,
                  onTap: () => _startChat(employee),
                );
              },
            ),
          ),
        ],
      )),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.hasAccount,
    required this.isStarting,
    required this.onTap,
  });

  final Map<String, dynamic> employee;
  final bool hasAccount;
  final bool isStarting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = employee['name']?.toString() ?? '';
    final jobTitle = employee['job_title']?.toString();
    final department = (employee['department_id'] is List) ? employee['department_id'][1] as String : null;
    final safe = OdooImage.sanitize(employee['image_128'] as String?);

    return Opacity(
      opacity: hasAccount ? 1 : 0.55,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                safe != null
                    ? CircleAvatar(radius: 22, backgroundImage: MemoryImage(base64Decode(safe)))
                    : CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.brandOrange.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTextStyles.style(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.brandOrange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.style(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [jobTitle, department].where((s) => s != null && s.isNotEmpty).join(' · '),
                        style: AppTextStyles.style(fontSize: 11.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!hasAccount) ...[
                        const SizedBox(height: 3),
                        Text('No login account', style: AppTextStyles.style(fontSize: 10.5, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                if (isStarting)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandBlue))
                else if (hasAccount)
                  const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.brandBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}