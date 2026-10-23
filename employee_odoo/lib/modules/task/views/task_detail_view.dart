import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../../data/models/task_record.dart';
import '../../../data/repositories/task_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/responsive.dart';

class TaskDetailView extends StatefulWidget {
  const TaskDetailView({super.key});

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> {
  TaskRecord? _task;
  List<TaskStage> _stages = [];
  bool _loading = true;
  bool _notFound = false;
  bool _movingStage = false;
  late TaskRepository _repo;

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
    _repo = TaskRepository(client!);
    final userId = Get.find<AuthController>().activeAccount.value?.userId;
    try {
      final task = await _repo.fetchById(id);
      List<TaskStage> stages = [];
      if (userId != null) {
        stages = await _repo.fetchPersonalStages(userId);
      }
      setState(() {
        _task = task;
        _stages = stages;
        _notFound = task == null;
        _loading = false;
      });
    } catch (e) {
      setState(() { _notFound = true; _loading = false; });
    }
  }

  Future<void> _moveToStage(TaskStage stage) async {
    if (_task == null || stage.id == _task!.stageId) return;
    setState(() => _movingStage = true);
    try {
      final ok = await _repo.updateStage(_task!.id, stage.id);
      if (ok) {
        await _load();
      } else {
        Get.snackbar('Failed', 'Could not update the stage, please try again', snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _movingStage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppMainAppBar(title: 'Task'),
      body: ResponsiveBody(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandBlue))
          : _notFound
          ? _buildNotFound()
          : _buildDetail(_task!)),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text('This task could not be found.', style: AppTextStyles.style(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(TaskRecord t) {
    final overdue = t.isOverdue;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.brandBlue.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      t.name,
                      style: AppTextStyles.style(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.white),
                    ),
                  ),
                  if (t.priority == TaskPriority.high)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.star_rounded, color: Colors.amberAccent, size: 22),
                    ),
                ],
              ),
              if (t.projectName != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 15, color: Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 6),
                    Text(t.projectName!, style: AppTextStyles.style(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _infoCard([
          if (t.stageName != null) _infoRow(Icons.flag_outlined, 'Stage', t.stageName!, AppColors.brandBlue),
          if (t.deadline != null)
            _infoRow(
              Icons.event_outlined,
              'Deadline',
              _formatDate(t.deadline!),
              overdue ? AppColors.error : AppColors.textPrimary,
            ),
        ]),
        if (t.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          _infoCard([
            _infoRow(Icons.notes_outlined, 'Description', t.description, AppColors.textPrimary, multiline: true),
          ]),
        ],
        if (_stages.length > 1) ...[
          const SizedBox(height: 20),
          Text('Move to Stage', style: AppTextStyles.style(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _stages.map((stage) {
              final isCurrent = stage.id == t.stageId;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _movingStage || isCurrent ? null : () => _moveToStage(stage),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.brandBlue : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isCurrent ? AppColors.brandBlue : AppColors.border),
                  ),
                  child: Text(
                    stage.name,
                    style: AppTextStyles.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? AppColors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_movingStage) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandBlue)),
          ],
        ],
      ],
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: AppColors.brandBlue.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color valueColor, {bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.brandBlue),
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
                  style: AppTextStyles.style(fontSize: 13.5, fontWeight: FontWeight.w600, color: valueColor),
                  maxLines: multiline ? null : 1,
                  overflow: multiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}