class TimesheetGridRow {
  TimesheetGridRow({
    required this.projectId,
    required this.projectName,
    this.taskId,
    this.taskName = '',
    Map<DateTime, double>? hoursByDay,
  }) : hoursByDay = hoursByDay ?? {};

  final int projectId;
  final String projectName;
  final int? taskId;
  final String taskName;
  final Map<DateTime, double> hoursByDay;

  String get rowKey => '$projectId-${taskId ?? 0}';

  double hoursOn(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return hoursByDay[key] ?? 0;
  }

  double get rowTotal =>
      hoursByDay.values.fold(0.0, (sum, value) => sum + value);

  String get label {
    if (taskName.isNotEmpty) return taskName;
    return projectName;
  }

  String get subtitle {
    if (taskName.isNotEmpty && projectName.isNotEmpty) return projectName;
    return '';
  }
}
