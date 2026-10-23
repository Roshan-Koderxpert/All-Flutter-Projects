import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../modules/auth/controllers/auth_controller.dart';
import '../theme/app_colors.dart';

void showTaskNotificationSheet(BuildContext context, int taskId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _TaskNotificationSheetBody(taskId: taskId),
  );
}

class _TaskNotificationSheetBody extends StatefulWidget {
  const _TaskNotificationSheetBody({required this.taskId});
  final int taskId;

  @override
  State<_TaskNotificationSheetBody> createState() => _TaskNotificationSheetBodyState();
}

class _TaskNotificationSheetBodyState extends State<_TaskNotificationSheetBody> {
  Map<String, dynamic>? _task;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Get.find<AuthController>().odooClient;
    try {
      final result = await client!.callKw({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [['id', '=', widget.taskId]],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'project_id', 'date_deadline', 'priority', 'description', 'stage_id'],
          'limit': 1,
        },
      });
      if (result is List && result.isNotEmpty) {
        setState(() {
          _task = Map<String, dynamic>.from(result.first as Map);
          _loading = false;
        });
      } else {
        setState(() {
          _notFound = true;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _notFound = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loading
          ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
          : _notFound
          ? _buildNotFound()
          : _buildDetail(_task!),
    );
  }

  Widget _buildNotFound() {
    return const SizedBox(
      height: 160,
      child: Center(child: Text('This task is no longer available.')),
    );
  }

  Widget _buildDetail(Map<String, dynamic> t) {
    final projectName = (t['project_id'] is List) ? t['project_id'][1] as String : '';
    final stageName = (t['stage_id'] is List) ? t['stage_id'][1] as String : '';
    final deadline = t['date_deadline'] is String ? t['date_deadline'] as String : null;    final description = _stripHtml(t['description'] is String ? t['description'] as String : '');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t['name'] is String ? t['name'] as String : '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (projectName.isNotEmpty) _infoRow(Icons.folder_outlined, 'Project', projectName),
        if (stageName.isNotEmpty) _infoRow(Icons.flag_outlined, 'Stage', stageName),
        if (deadline != null) _infoRow(Icons.event_outlined, 'Deadline', deadline),
        if (description.isNotEmpty) _infoRow(Icons.notes_outlined, 'Description', description),
        const SizedBox(height: 8),
      ],
    );
  }

  String _stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}