import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_logger.dart';
import '../../../data/models/timesheet_chart_data.dart';
import '../../../data/models/timesheet_grid_row.dart';
import '../../../data/models/timesheet_line.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/timesheet_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_controller.dart';

enum TimesheetViewMode { grid, kanban, list, graph }

enum TimesheetGraphType { bar, line, pie }

enum TimesheetGraphMeasure { timeSpent, timeCosts, count }

class TimesheetController extends GetxController {
  final AuthController _auth = Get.find<AuthController>();
  final HomeController _home = Get.find<HomeController>();

  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final isLoadingTasks = false.obs;
  final errorMessage = ''.obs;
  final viewMode = TimesheetViewMode.grid.obs;
  final graphType = TimesheetGraphType.bar.obs;
  final graphMeasure = TimesheetGraphMeasure.timeSpent.obs;
  final weekStart = Rx<DateTime>(_startOfWeek(DateTime.now()));

  /// Odoo graph palette (pie: blue, coral, teal, orange, …).
  static const odooGraphPalette = [
    Color(0xFF5DADE2),
    Color(0xFFEC7063),
    Color(0xFF48C9B0),
    Color(0xFFF5B041),
    Color(0xFFAF7AC5),
    Color(0xFF58D68D),
    Color(0xFF5D6D7E),
    Color(0xFFF1948A),
  ];

  final weekLines = <TimesheetLine>[].obs;
  final allLines = <TimesheetLine>[].obs;
  final projects = <TimesheetProjectOption>[].obs;
  final tasks = <TimesheetTaskOption>[].obs;

  TimesheetRepository? get _repo {
    final client = _auth.odooClient;
    if (client == null) return null;
    return TimesheetRepository(client);
  }

  List<TimesheetLine> get lines {
    if (viewMode.value == TimesheetViewMode.list) return allLines;
    return weekLines;
  }

  List<TimesheetLine> get sortedWeekLines {
    final copy = List<TimesheetLine>.from(weekLines);
    copy.sort((a, b) {
      final ad = a.date;
      final bd = b.date;
      if (ad == null && bd == null) return b.id.compareTo(a.id);
      if (ad == null) return 1;
      if (bd == null) return -1;
      final cmp = bd.compareTo(ad);
      return cmp != 0 ? cmp : b.id.compareTo(a.id);
    });
    return copy;
  }

  double get totalHours =>
      lines.fold(0.0, (sum, line) => sum + line.hours);

  List<DateTime> get weekDays => List.generate(
        7,
        (i) => weekStart.value.add(Duration(days: i)),
      );

  DateTime get weekEnd => weekDays.last;

  void setViewMode(TimesheetViewMode mode) {
    viewMode.value = mode;
    if ((mode == TimesheetViewMode.list || mode == TimesheetViewMode.graph) &&
        allLines.isEmpty) {
      loadAllLines();
    }
  }

  void setGraphType(TimesheetGraphType type) => graphType.value = type;

  void setGraphMeasure(TimesheetGraphMeasure measure) =>
      graphMeasure.value = measure;

  TimesheetGraphChartData get graphChartData {
    graphMeasure.value;
    allLines.length;

    final weekBuckets = <String, Map<String, double>>{};
    final weekMeta = <String, ({int year, int week})>{};
    final projectTotals = <String, double>{};

    for (final line in allLines) {
      final date = line.date;
      if (date == null) continue;

      final iso = _isoWeekYearAndNumber(date);
      final weekKey = '${iso.year}-${iso.week}';
      final project = _gridProjectName(line);
      final value = _measureValue(line);

      weekMeta.putIfAbsent(weekKey, () => (year: iso.year, week: iso.week));
      weekBuckets.putIfAbsent(weekKey, () => {});
      weekBuckets[weekKey]![project] =
          (weekBuckets[weekKey]![project] ?? 0) + value;
      projectTotals[project] = (projectTotals[project] ?? 0) + value;
    }

    final sortedProjects = projectTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final projectLabels = sortedProjects.map((e) => e.key).toList();
    final projectColors = <String, Color>{
      for (var i = 0; i < projectLabels.length; i++)
        projectLabels[i]: odooGraphPalette[i % odooGraphPalette.length],
    };

    var groups = weekMeta.entries.map((entry) {
      final values = weekBuckets[entry.key] ?? {};
      final total = values.values.fold(0.0, (sum, v) => sum + v);
      final meta = entry.value;
      return TimesheetWeekChartGroup(
        label: 'W${meta.week} ${meta.year}',
        year: meta.year,
        week: meta.week,
        valuesByProject: values,
        total: total,
      );
    }).toList()
      ..sort((a, b) {
        if (a.year != b.year) return a.year.compareTo(b.year);
        return a.week.compareTo(b.week);
      });

    var maxValue = 0.0;
    for (final group in groups) {
      for (final value in group.valuesByProject.values) {
        if (value > maxValue) maxValue = value;
      }
    }

    return TimesheetGraphChartData(
      weekGroups: groups,
      projectLabels: projectLabels,
      projectColors: projectColors,
      maxValue: maxValue > 0 ? maxValue : 1,
    );
  }

  List<TimesheetPieChartSlice> get pieChartSlices {
    final buckets = <String, double>{};
    final weekLabels = <String, String>{};
    final projectLabels = <String, String>{};

    for (final line in allLines) {
      final date = line.date;
      if (date == null) continue;

      final iso = _isoWeekYearAndNumber(date);
      final weekLabel = 'W${iso.week} ${iso.year}';
      final project = _gridProjectName(line);
      final key = '$weekLabel|$project';
      final value = _measureValue(line);

      buckets[key] = (buckets[key] ?? 0) + value;
      weekLabels[key] = weekLabel;
      projectLabels[key] = project;
    }

    final entries = buckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return List.generate(entries.length, (i) {
      final entry = entries[i];
      final project = projectLabels[entry.key] ?? 'Internal';
      return TimesheetPieChartSlice(
        weekLabel: weekLabels[entry.key] ?? '',
        projectLabel: project,
        value: entry.value,
        color: odooGraphPalette[i % odooGraphPalette.length],
      );
    });
  }

  String graphMeasureLabel(TimesheetGraphMeasure measure) {
    return switch (measure) {
      TimesheetGraphMeasure.timeSpent => 'Time Spent',
      TimesheetGraphMeasure.timeCosts => 'Time Costs',
      TimesheetGraphMeasure.count => 'Count',
    };
  }

  double _measureValue(TimesheetLine line) {
    return switch (graphMeasure.value) {
      TimesheetGraphMeasure.timeSpent => line.hours,
      TimesheetGraphMeasure.timeCosts => line.cost,
      TimesheetGraphMeasure.count => 1,
    };
  }

  static ({int year, int week}) _isoWeekYearAndNumber(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final thursday = local.add(Duration(days: 4 - local.weekday));
    final year = thursday.year;
    final jan4 = DateTime(year, 1, 4);
    final week1Monday =
        jan4.subtract(Duration(days: jan4.weekday - DateTime.monday));
    final monday = local.subtract(Duration(days: local.weekday - DateTime.monday));
    final week = 1 + monday.difference(week1Monday).inDays ~/ 7;
    return (year: year, week: week);
  }

  void previousWeek() {
    weekStart.value = weekStart.value.subtract(const Duration(days: 7));
    loadWeekLines();
  }

  void nextWeek() {
    weekStart.value = weekStart.value.add(const Duration(days: 7));
    loadWeekLines();
  }

  void goToCurrentWeek() {
    weekStart.value = _startOfWeek(DateTime.now());
    loadWeekLines();
  }

  List<TimesheetGridRow> buildGridRows() {
    final rows = <String, TimesheetGridRow>{};

    for (final line in weekLines) {
      if (line.date == null) continue;

      final projectId = line.projectId ?? 0;
      final key = '$projectId-${line.taskId ?? 0}';
      final day = DateTime(
        line.date!.year,
        line.date!.month,
        line.date!.day,
      );

      rows.putIfAbsent(
        key,
        () => TimesheetGridRow(
          projectId: projectId,
          projectName: _gridProjectName(line),
          taskId: line.taskId,
          taskName: line.taskName,
        ),
      );

      final row = rows[key]!;
      row.hoursByDay[day] = (row.hoursByDay[day] ?? 0) + line.hours;
    }

    final sorted = rows.values.toList()
      ..sort((a, b) {
        final projectCmp =
            a.projectName.toLowerCase().compareTo(b.projectName.toLowerCase());
        if (projectCmp != 0) return projectCmp;
        return a.taskName.toLowerCase().compareTo(b.taskName.toLowerCase());
      });
    return sorted;
  }

  String _gridProjectName(TimesheetLine line) {
    if (line.projectName.isNotEmpty) return line.projectName;
    if (line.taskName.isNotEmpty) return line.taskName;
    if (line.description.isNotEmpty && line.description != '/') {
      return line.description;
    }
    return 'Internal';
  }

  double dailyTotal(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return weekLines
        .where((line) {
          if (line.date == null) return false;
          final d = DateTime(line.date!.year, line.date!.month, line.date!.day);
          return d == key;
        })
        .fold(0.0, (sum, line) => sum + line.hours);
  }

  double get weekGridTotal =>
      weekLines.fold(0.0, (sum, line) => sum + line.hours);

  /// Finds a single timesheet line for a grid/kanban cell (project + task + day).
  TimesheetLine? findLineForCell({
    required int projectId,
    int? taskId,
    required DateTime date,
    List<TimesheetLine>? source,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final taskKey = taskId ?? 0;
    final lines = (source ?? weekLines).where((line) {
      if (line.id <= 0 || line.date == null) return false;
      final lineDay = DateTime(
        line.date!.year,
        line.date!.month,
        line.date!.day,
      );
      if (lineDay != day) return false;
      if ((line.projectId ?? 0) != projectId) return false;
      if ((line.taskId ?? 0) != taskKey) return false;
      return true;
    }).toList();

    if (lines.isEmpty) return null;
    if (lines.length == 1) return lines.first;
    lines.sort((a, b) => b.id.compareTo(a.id));
    return lines.first;
  }

  int countLinesForCell({
    required int projectId,
    int? taskId,
    required DateTime date,
    List<TimesheetLine>? source,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final taskKey = taskId ?? 0;
    return (source ?? weekLines).where((line) {
      if (line.id <= 0 || line.date == null) return false;
      final lineDay = DateTime(
        line.date!.year,
        line.date!.month,
        line.date!.day,
      );
      if (lineDay != day) return false;
      if ((line.projectId ?? 0) != projectId) return false;
      if ((line.taskId ?? 0) != taskKey) return false;
      return true;
    }).length;
  }

  static DateTime _startOfWeek(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    // Odoo timesheet grid: Sunday → Saturday
    final daysSinceSunday = local.weekday % DateTime.daysPerWeek;
    return local.subtract(Duration(days: daysSinceSunday));
  }

  int? get _userId => _auth.activeAccount.value?.userId;

  Future<List<TimesheetLine>> _fetchLines({
    required int employeeId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 200,
  }) {
    final repo = _repo!;
    return repo.fetchMyTimesheets(
      employeeId: employeeId,
      userId: _userId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      limit: limit,
    );
  }

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<int?> _resolveEmployeeId() async {
    // Employee mode: scope to the employee from login, never the shared user.
    final scoped = _auth.scopedEmployeeId;
    if (scoped != null) {
      _home.employeeId.value = scoped;
      return scoped;
    }

    final existing = _home.employeeId.value;
    if (existing != null) return existing;

    final userId = _auth.activeAccount.value?.userId;
    final client = _auth.odooClient;
    if (userId == null || client == null) return null;

    try {
      final resolved = await EmployeeRepository(client).resolveForUser(userId);
      if (resolved == null) return null;
      _home.employeeId.value = resolved.id;
      return resolved.id;
    } catch (e, st) {
      ApiLogger.error('_resolveEmployeeId', e, st);
      return null;
    }
  }

  Future<void> loadAll() async {
    final repo = _repo;
    if (repo == null) {
      errorMessage.value = 'Not connected to server';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final empId = await _resolveEmployeeId();
      projects.assignAll(await repo.fetchTimesheetProjects());

      if (empId == null) {
        errorMessage.value = 'Employee profile not found';
        weekLines.clear();
        allLines.clear();
        return;
      }

      await Future.wait([
        loadWeekLines(employeeId: empId, snapToDataWeek: true),
        if (viewMode.value == TimesheetViewMode.list)
          loadAllLines(employeeId: empId),
      ]);
    } catch (e, st) {
      ApiLogger.error('loadAll failed', e, st);
      errorMessage.value = 'Failed to load timesheets';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadWeekLines({int? employeeId, bool snapToDataWeek = false}) async {
    final repo = _repo;
    if (repo == null) return;

    final empId = employeeId ?? await _resolveEmployeeId();
    if (empId == null) return;

    var lines = await _fetchLines(
      employeeId: empId,
      dateFrom: weekStart.value,
      dateTo: weekEnd,
      limit: 500,
    );

    final onCurrentWeek =
        weekStart.value == _startOfWeek(DateTime.now());
    if (lines.isEmpty && snapToDataWeek && onCurrentWeek) {
      final recent = await _fetchLines(employeeId: empId, limit: 100);
      final dated = recent.where((l) => l.date != null).toList();
      if (dated.isNotEmpty) {
        dated.sort((a, b) => b.date!.compareTo(a.date!));
        weekStart.value = _startOfWeek(dated.first.date!);
        lines = await _fetchLines(
          employeeId: empId,
          dateFrom: weekStart.value,
          dateTo: weekEnd,
          limit: 500,
        );
      }
    }

    weekLines.assignAll(lines);
  }

  Future<void> loadAllLines({int? employeeId}) async {
    final repo = _repo;
    if (repo == null) return;

    final empId = employeeId ?? await _resolveEmployeeId();
    if (empId == null) return;

    allLines.assignAll(
      await _fetchLines(employeeId: empId, limit: 500),
    );
  }

  Future<void> loadTasksForProject(int projectId) async {
    final repo = _repo;
    if (repo == null) return;

    isLoadingTasks.value = true;
    try {
      tasks.assignAll(await repo.fetchTasksForProject(projectId));
    } catch (e, st) {
      ApiLogger.error('loadTasksForProject', e, st);
      tasks.clear();
    } finally {
      isLoadingTasks.value = false;
    }
  }

  void clearTasks() {
    tasks.clear();
  }

  Future<bool> quickAddMinutes(TimesheetLine line, {double minutes = 15}) async {
    final projectId = line.projectId;
    if (projectId == null || projectId <= 0) {
      Get.snackbar(
        'Timesheet',
        'Cannot quick-add time without a project',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    return addLine(
      projectId: projectId,
      taskId: line.taskId,
      date: line.date ?? DateTime.now(),
      description: line.description,
      hours: minutes / 60,
    );
  }

  Future<bool> saveLine({
    int? lineId,
    required int projectId,
    int? taskId,
    required DateTime date,
    required String description,
    required double hours,
  }) async {
    if (lineId != null && lineId > 0) {
      return updateLine(
        lineId: lineId,
        projectId: projectId,
        taskId: taskId,
        date: date,
        description: description,
        hours: hours,
      );
    }
    return addLine(
      projectId: projectId,
      taskId: taskId,
      date: date,
      description: description,
      hours: hours,
    );
  }

  Future<bool> updateLine({
    required int lineId,
    required int projectId,
    int? taskId,
    required DateTime date,
    required String description,
    required double hours,
  }) async {
    final repo = _repo;
    if (repo == null) {
      Get.snackbar('Timesheet', 'Not connected', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (hours <= 0) {
      Get.snackbar(
        'Timesheet',
        'Enter valid time (HH:MM)',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final empId = await _resolveEmployeeId();
    if (empId == null) {
      Get.snackbar(
        'Timesheet',
        'Employee profile not found',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    isSubmitting.value = true;
    try {
      await repo.updateTimesheet(
        lineId: lineId,
        hours: hours,
        description: description,
        date: date,
        projectId: projectId,
        taskId: taskId,
      );

      await Future.wait([
        loadWeekLines(employeeId: empId),
        if (viewMode.value == TimesheetViewMode.list || allLines.isNotEmpty)
          loadAllLines(employeeId: empId),
      ]);

      Get.snackbar('Timesheet', 'Line updated', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e, st) {
      ApiLogger.error('updateLine', e, st);
      Get.snackbar(
        'Timesheet',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> addLine({
    required int projectId,
    int? taskId,
    required DateTime date,
    required String description,
    required double hours,
  }) async {
    final repo = _repo;
    if (repo == null) {
      Get.snackbar('Timesheet', 'Not connected', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (hours <= 0) {
      Get.snackbar(
        'Timesheet',
        'Enter valid time (HH:MM)',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final empId = await _resolveEmployeeId();
    if (empId == null) {
      Get.snackbar(
        'Timesheet',
        'Employee profile not found',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    isSubmitting.value = true;
    try {
      await repo.createTimesheet(
        employeeId: empId,
        userId: _auth.activeAccount.value?.userId,
        projectId: projectId,
        taskId: taskId,
        date: date,
        hours: hours,
        description: description,
      );

      await Future.wait([
        loadWeekLines(employeeId: empId),
        if (viewMode.value == TimesheetViewMode.list ||
            allLines.isNotEmpty)
          loadAllLines(employeeId: empId),
      ]);

      Get.snackbar('Timesheet', 'Line saved', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e, st) {
      ApiLogger.error('addLine', e, st);
      Get.snackbar(
        'Timesheet',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
