enum TaskPriority { normal, high }

TaskPriority _parsePriority(dynamic value) {
  // Odoo's project.task 'priority' field: '0' = normal/low, '1' = high (star starred).
  if (value == '1') return TaskPriority.high;
  return TaskPriority.normal;
}

class TaskRecord {
  final int id;
  final String name;
  final String? projectName;
  final int? projectId;
  final String? stageName;
  final int? stageId;
  final DateTime? deadline;
  final TaskPriority priority;
  final String description;

  TaskRecord({
    required this.id,
    required this.name,
    this.projectName,
    this.projectId,
    this.stageName,
    this.stageId,
    this.deadline,
    this.priority = TaskPriority.normal,
    this.description = '',
  });

  factory TaskRecord.fromOdoo(Map<String, dynamic> row) {
    DateTime? deadline;
    final rawDeadline = row['date_deadline'];
    if (rawDeadline is String && rawDeadline.isNotEmpty) {
      deadline = DateTime.tryParse(rawDeadline);
    }

    String stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return TaskRecord(
      id: row['id'] as int,
      name: row['name'] is String ? row['name'] as String : '',
      projectName: (row['project_id'] is List) ? row['project_id'][1] as String : null,
      projectId: (row['project_id'] is List) ? row['project_id'][0] as int : null,
      stageName: (row['personal_stage_type_id'] is List) ? row['personal_stage_type_id'][1] as String : null,
      stageId: (row['personal_stage_type_id'] is List) ? row['personal_stage_type_id'][0] as int : null,
      deadline: deadline,
      priority: _parsePriority(row['priority']),
      description: row['description'] is String ? stripHtml(row['description'] as String) : '',
    );
  }

  bool get isOverdue {
    if (deadline == null) return false;
    final today = DateTime.now();
    final dateOnly = DateTime(deadline!.year, deadline!.month, deadline!.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    return dateOnly.isBefore(todayOnly);
  }

  bool get isDueToday {
    if (deadline == null) return false;
    final now = DateTime.now();
    return deadline!.year == now.year && deadline!.month == now.month && deadline!.day == now.day;
  }
}