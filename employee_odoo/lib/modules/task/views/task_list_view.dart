import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../../data/models/task_record.dart';
import '../controllers/task_controller.dart';
import '../../../core/utils/responsive.dart';

class TaskListView extends GetView<TaskController> {
  const TaskListView({super.key});

  @override
  Widget build(BuildContext context) {
    controller.loadAll();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppMainAppBar(title: 'My Tasks'),
      body: ResponsiveBody(child: Obx(() {
        switch (controller.status.value) {
          case TaskModuleStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.brandBlue));
          case TaskModuleStatus.unavailable:
            return _buildUnavailable();
          case TaskModuleStatus.error:
            return _buildError();
          case TaskModuleStatus.available:
            return Column(
              children: [
                _buildSummaryRow(),
                _buildSearchAndToggle(),
                Expanded(
                  child: Obx(() => controller.viewMode.value == TaskViewMode.list
                      ? _buildListMode()
                      : _buildKanbanMode()),
                ),
              ],
            );
        }
      })),
    );
  }

  Widget _buildSummaryRow() {
    return Obx(() => Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 14),
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
          _summaryTile('Total', controller.tasks.length.toString(), AppColors.brandBlue),
          _verticalDivider(),
          _summaryTile('Due Today', controller.dueTodayCount.toString(), AppColors.brandOrange),
          _verticalDivider(),
          _summaryTile('Overdue', controller.overdueCount.toString(), AppColors.error),
        ],
      ),
    ));
  }

  Widget _verticalDivider() => Container(width: 1, height: 34, color: AppColors.border);

  Widget _summaryTile(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.style(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.style(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSearchAndToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 19, color: AppColors.brandBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: controller.onSearchChanged,
                      style: AppTextStyles.style(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search tasks',
                        hintStyle: AppTextStyles.style(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Obx(() => Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _toggleIcon(Icons.view_list_rounded, TaskViewMode.list),
                _toggleIcon(Icons.view_kanban_rounded, TaskViewMode.kanban),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _toggleIcon(IconData icon, TaskViewMode mode) {
    final active = controller.viewMode.value == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => controller.setViewMode(mode),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active ? AppColors.brandBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: active ? AppColors.white : AppColors.textSecondary),
      ),
    );
  }

  Widget _buildListMode() {
    return Obx(() {
      final list = controller.filteredTasks;
      if (list.isEmpty) return const _EmptyState();
      return RefreshIndicator(
        color: AppColors.brandBlue,
        onRefresh: controller.loadAll,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _TaskCard(task: list[index]),
        ),
      );
    });
  }

  Widget _buildKanbanMode() {
    return Obx(() {
      final grouped = controller.groupedByStage;
      if (grouped.isEmpty || controller.filteredTasks.isEmpty) return const _EmptyState();
      return RefreshIndicator(
        color: AppColors.brandBlue,
        onRefresh: controller.loadAll,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            for (final entry in grouped.entries)
              _KanbanColumn(stageName: entry.key, tasks: entry.value),
          ],
        ),
      );
    });
  }

  Widget _buildUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('My Tasks isn\'t available', style: AppTextStyles.style(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Your organization hasn\'t enabled the Project app on this Odoo server.',
              style: AppTextStyles.style(fontSize: 12.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Something went wrong loading your tasks.', style: AppTextStyles.style(fontSize: 13.5)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: controller.loadAll, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_rtl_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No tasks assigned to you', style: AppTextStyles.style(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Tasks assigned to you in Odoo Project will show up here.',
              style: AppTextStyles.style(fontSize: 12.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskRecord task;

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue;
    final dueToday = task.isDueToday;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.toNamed(AppRoutes.taskDetail, arguments: task.id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: overdue ? AppColors.error.withValues(alpha: 0.3) : AppColors.border.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandBlue.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
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
                      task.name,
                      style: AppTextStyles.style(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.priority == TaskPriority.high)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.star_rounded, size: 18, color: AppColors.brandOrange),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (task.projectName != null) _tag(Icons.folder_outlined, task.projectName!, AppColors.brandBlue),
                  if (task.stageName != null) _tag(Icons.flag_outlined, task.stageName!, AppColors.brandBlueLight),
                  if (task.deadline != null)
                    _tag(
                      Icons.event_outlined,
                      _formatDate(task.deadline!),
                      overdue ? AppColors.error : (dueToday ? AppColors.brandOrange : AppColors.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _tag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.style(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({required this.stageName, required this.tasks});

  final String stageName;
  final List<TaskRecord> tasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    stageName,
                    style: AppTextStyles.style(fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: AppTextStyles.style(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brandBlue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: tasks.isEmpty
                ? Center(
              child: Text(
                'No tasks',
                style: AppTextStyles.style(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            )
                : ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
            ),
          ),
        ],
      ),
    );
  }
}