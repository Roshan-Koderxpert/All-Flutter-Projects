import 'package:flutter/material.dart';

class TimesheetWeekChartGroup {
  const TimesheetWeekChartGroup({
    required this.label,
    required this.year,
    required this.week,
    required this.valuesByProject,
    required this.total,
  });

  final String label;
  final int year;
  final int week;
  final Map<String, double> valuesByProject;
  final double total;
}

class TimesheetPieChartSlice {
  const TimesheetPieChartSlice({
    required this.weekLabel,
    required this.projectLabel,
    required this.value,
    required this.color,
  });

  final String weekLabel;
  final String projectLabel;
  final double value;
  final Color color;

  String get displayLabel => '$weekLabel / $projectLabel';
}

class TimesheetGraphChartData {
  const TimesheetGraphChartData({
    required this.weekGroups,
    required this.projectLabels,
    required this.projectColors,
    required this.maxValue,
  });

  final List<TimesheetWeekChartGroup> weekGroups;
  final List<String> projectLabels;
  final Map<String, Color> projectColors;
  final double maxValue;

  bool get isEmpty =>
      weekGroups.isEmpty ||
      weekGroups.every((g) => g.total <= 0);
}
