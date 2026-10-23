import '../../core/utils/odoo_datetime.dart';

class TimesheetProjectOption {
  TimesheetProjectOption({required this.id, required this.name});

  final int id;
  final String name;
}

class TimesheetTaskOption {
  TimesheetTaskOption({required this.id, required this.name});

  final int id;
  final String name;
}

class TimesheetLine {
  TimesheetLine({
    required this.id,
    required this.description,
    this.date,
    this.hours = 0,
    this.cost = 0,
    this.projectId,
    this.projectName = '',
    this.taskId,
    this.taskName = '',
  });

  final int id;
  final String description;
  final DateTime? date;
  final double hours;
  final double cost;
  final int? projectId;
  final String projectName;
  final int? taskId;
  final String taskName;

  String get dateLabel => OdooDateTime.formatDateSlash(date);

  /// Primary label on Odoo kanban cards (project name).
  String get kanbanTitle {
    if (projectName.isNotEmpty) return projectName;
    if (taskName.isNotEmpty) return taskName;
    return 'Internal';
  }

  /// Secondary line (task name when project is set).
  String get kanbanSubtitle {
    if (projectName.isNotEmpty && taskName.isNotEmpty) return taskName;
    return '';
  }

  /// Bottom note on kanban cards (description).
  String get kanbanFooter {
    if (displayDescription.isEmpty) return '';
    if (kanbanSubtitle == displayDescription) return '';
    return displayDescription;
  }

  /// Odoo uses `/` for empty descriptions.
  String get displayDescription {
    if (description.isEmpty || description == '/') return '';
    return description;
  }

  factory TimesheetLine.fromOdoo(Map<String, dynamic> json) {
    final project = json['project_id'];
    int? projectId;
    var projectName = '';
    if (project is List && project.isNotEmpty) {
      projectId = project[0] as int?;
      if (project.length > 1) projectName = project[1]?.toString() ?? '';
    }

    final task = json['task_id'];
    int? taskId;
    var taskName = '';
    if (task is List && task.isNotEmpty) {
      taskId = task[0] as int?;
      if (task.length > 1) taskName = task[1]?.toString() ?? '';
    }

    final amount = json['unit_amount'];
    var hours = 0.0;
    if (amount is num) hours = amount.toDouble();

    final costField = json['amount'];
    var cost = 0.0;
    if (costField is num) cost = costField.abs().toDouble();

    return TimesheetLine(
      id: json['id'] is int ? json['id'] as int : 0,
      description: _stringField(json['name']),
      date: OdooDateTime.parseDate(json['date']),
      hours: hours,
      cost: cost,
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskName: taskName,
    );
  }

  static String _stringField(dynamic value) {
    if (value == false || value == null) return '';
    return value.toString();
  }
}
