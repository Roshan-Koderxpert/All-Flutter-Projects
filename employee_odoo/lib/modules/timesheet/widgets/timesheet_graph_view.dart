import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../data/models/timesheet_chart_data.dart';
import '../controllers/timesheet_controller.dart';
import '../utils/timesheet_ui_utils.dart';

class TimesheetGraphView extends StatelessWidget {
  const TimesheetGraphView({super.key, required this.controller});

  final TimesheetController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.graphType.value;
      controller.graphMeasure.value;
      controller.allLines.length;

      final graphType = controller.graphType.value;
      final measure = controller.graphMeasure.value;
      final chartData = controller.graphChartData;
      final pieSlices = controller.pieChartSlices;
      final hasData = !chartData.isEmpty;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OdooGraphToolbar(controller: controller),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: hasData
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                        child: switch (graphType) {
                          TimesheetGraphType.bar => _WeeklyGroupedBarChart(
                              data: chartData,
                              measure: measure,
                            ),
                          TimesheetGraphType.line => _WeeklyMultiLineChart(
                              data: chartData,
                              measure: measure,
                            ),
                          TimesheetGraphType.pie => _InteractivePieChart(
                              controller: controller,
                              slices: pieSlices,
                              measure: measure,
                            ),
                        },
                      )
                    : Center(
                        child: Text(
                          'No timesheet data',
                          style: AppTextStyles.style(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _OdooGraphToolbar extends StatelessWidget {
  const _OdooGraphToolbar({required this.controller});

  final TimesheetController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final measure = controller.graphMeasure.value;
      final graphType = controller.graphType.value;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            AppPopupMenuButton<TimesheetGraphMeasure>(
              tooltip: 'Measures',
              menuMinWidth: 172,
              offset: const Offset(0, 36),
              onSelected: controller.setGraphMeasure,
              itemBuilder: (context) => [
                _measureItem(
                  TimesheetGraphMeasure.timeSpent,
                  'Time Spent',
                  measure,
                  showDivider: true,
                ),
                _measureItem(
                  TimesheetGraphMeasure.timeCosts,
                  'Time Costs',
                  measure,
                  showDivider: true,
                ),
                _measureItem(
                  TimesheetGraphMeasure.count,
                  'Count',
                  measure,
                ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Measures',
                      style: AppTextStyles.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: AppColors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ToolbarIconButton(
              icon: Icons.bar_chart_rounded,
              selected: graphType == TimesheetGraphType.bar,
              onTap: () => controller.setGraphType(TimesheetGraphType.bar),
            ),
            _ToolbarIconButton(
              icon: Icons.show_chart_rounded,
              selected: graphType == TimesheetGraphType.line,
              onTap: () => controller.setGraphType(TimesheetGraphType.line),
            ),
            _ToolbarIconButton(
              icon: Icons.pie_chart_outline_rounded,
              selected: graphType == TimesheetGraphType.pie,
              onTap: () => controller.setGraphType(TimesheetGraphType.pie),
            ),
          ],
        ),
      );
    });
  }

  PopupMenuEntry<TimesheetGraphMeasure> _measureItem(
    TimesheetGraphMeasure value,
    String label,
    TimesheetGraphMeasure selected, {
    bool showDivider = false,
  }) {
    final isSelected = value == selected;
    return AppDropdownStyle.popupItem<TimesheetGraphMeasure>(
      value: value,
      showDivider: showDivider,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check, size: 16, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: selected
            ? AppColors.brandBlue.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected ? AppColors.brandBlue : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OdooHorizontalChartLegend extends StatefulWidget {
  const _OdooHorizontalChartLegend({
    required this.labels,
    required this.colors,
  });

  final List<String> labels;
  final Map<String, Color> colors;

  @override
  State<_OdooHorizontalChartLegend> createState() =>
      _OdooHorizontalChartLegendState();
}

class _OdooHorizontalChartLegendState extends State<_OdooHorizontalChartLegend> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        primary: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
            children: widget.labels.map((label) {
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: widget.colors[label] ?? AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        label,
                        style: AppTextStyles.style(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
    );
  }
}

class _ScrollableChartLegend extends StatefulWidget {
  const _ScrollableChartLegend({
    required this.labels,
    required this.colors,
  });

  final List<String> labels;
  final Map<String, Color> colors;

  @override
  State<_ScrollableChartLegend> createState() => _ScrollableChartLegendState();
}

class _ScrollableChartLegendState extends State<_ScrollableChartLegend> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.75),
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          primary: false,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.labels.map((label) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: widget.colors[label] ?? AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: AppTextStyles.style(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
  }
}

class _InteractivePieChart extends StatefulWidget {
  const _InteractivePieChart({
    required this.controller,
    required this.slices,
    required this.measure,
  });

  final TimesheetController controller;
  final List<TimesheetPieChartSlice> slices;
  final TimesheetGraphMeasure measure;

  static const double _minSliceShare = 0.028;

  @override
  State<_InteractivePieChart> createState() => _InteractivePieChartState();
}

class _InteractivePieChartState extends State<_InteractivePieChart> {
  int? _activeIndex;
  final ScrollController _legendScrollController = ScrollController();

  @override
  void dispose() {
    _legendScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _InteractivePieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measure != widget.measure ||
        oldWidget.slices.length != widget.slices.length) {
      _activeIndex = null;
    }
  }

  void _setActive(int? index) {
    if (_activeIndex == index) return;
    setState(() => _activeIndex = index);
  }

  List<TimesheetPieChartSlice> get _visibleSlices =>
      widget.slices.where((s) => s.value > 0).toList();

  @override
  Widget build(BuildContext context) {
    final slices = _visibleSlices;
    final total = slices.fold(0.0, (sum, s) => sum + s.value);
    if (total <= 0) return const SizedBox.shrink();

    final active = _activeIndex != null &&
            _activeIndex! >= 0 &&
            _activeIndex! < slices.length
        ? slices[_activeIndex!]
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = (constraints.maxWidth < 360
                ? constraints.maxWidth * 0.82
                : math.min(constraints.maxWidth, constraints.maxHeight * 0.55) *
                    0.88)
            .clamp(120.0, 220.0);
        final sectionRadius = (chartSize / 2) - 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: SizedBox(
                  width: chartSize,
                  height: chartSize,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 1.2,
                      centerSpaceRadius: 0,
                      startDegreeOffset: -90,
                      borderData: FlBorderData(show: false),
                      pieTouchData: PieTouchData(
                        enabled: true,
                        longPressDuration:
                            const Duration(milliseconds: 250),
                        touchCallback: _onPieTouch,
                      ),
                      sections: _buildSections(
                        slices,
                        total: total,
                        sectionRadius: sectionRadius,
                      ),
                    ),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
            ),
            if (active != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: _PieTooltip(
                  measureLabel:
                      widget.controller.graphMeasureLabel(widget.measure),
                  slice: active,
                  total: total,
                  measure: widget.measure,
                ),
              ),
            const SizedBox(height: 4),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.75),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: _legendScrollController,
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: _PieOdooLegend(
                        slices: slices,
                        activeIndex: _activeIndex,
                        onHoldStart: _setActive,
                        onHoldEnd: () => _setActive(null),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<double> _visualSliceValues(
    List<TimesheetPieChartSlice> slices,
    double total,
  ) {
    if (slices.isEmpty || total <= 0) return const [];

    final minValue = total * _InteractivePieChart._minSliceShare;
    final boosted =
        slices.map((slice) => math.max(slice.value, minValue)).toList();
    final boostedTotal = boosted.fold(0.0, (sum, value) => sum + value);
    if (boostedTotal <= 0) return boosted;

    return boosted.map((value) => (value / boostedTotal) * total).toList();
  }

  List<PieChartSectionData> _buildSections(
    List<TimesheetPieChartSlice> slices, {
    required double total,
    required double sectionRadius,
  }) {
    final visualValues = _visualSliceValues(slices, total);

    return List.generate(slices.length, (i) {
      final slice = slices[i];
      final isActive = _activeIndex == i;

      return PieChartSectionData(
        value: visualValues[i],
        color: isActive
            ? slice.color
            : slice.color.withValues(alpha: 0.9),
        showTitle: false,
        radius: sectionRadius,
        borderSide: isActive
            ? const BorderSide(color: Colors.white, width: 1.5)
            : BorderSide.none,
      );
    });
  }

  void _onPieTouch(FlTouchEvent event, PieTouchResponse? response) {
    final index = response?.touchedSection?.touchedSectionIndex;

    if (event is FlLongPressStart) {
      if (index != null && index >= 0) _setActive(index);
      return;
    }

    if (event is FlLongPressMoveUpdate) {
      if (index != null && index >= 0) _setActive(index);
      return;
    }

    if (event is FlLongPressEnd || event is FlTapCancelEvent) {
      _setActive(null);
      return;
    }

    if (event is FlTapUpEvent) {
      if (!event.isInterestedForInteractions) {
        _setActive(null);
        return;
      }
      if (index != null && index >= 0) {
        _setActive(_activeIndex == index ? null : index);
      }
    }
  }
}

class _PieOdooLegend extends StatelessWidget {
  const _PieOdooLegend({
    required this.slices,
    required this.activeIndex,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final List<TimesheetPieChartSlice> slices;
  final int? activeIndex;
  final ValueChanged<int> onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: slices.asMap().entries.map((entry) {
        final i = entry.key;
        final slice = entry.value;
        final isActive = activeIndex == i;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (_) => onHoldStart(i),
            onLongPressEnd: (_) => onHoldEnd(),
            onTap: () {
              if (activeIndex == i) {
                onHoldEnd();
              } else {
                onHoldStart(i);
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: slice.color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slice.displayLabel,
                    style: AppTextStyles.style(
                      fontSize: 11,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PieTooltip extends StatelessWidget {
  const _PieTooltip({
    required this.measureLabel,
    required this.slice,
    required this.total,
    required this.measure,
  });

  final String measureLabel;
  final TimesheetPieChartSlice slice;
  final double total;
  final TimesheetGraphMeasure measure;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (slice.value / total) * 100 : 0.0;
    final valueText = _formatValue(slice.value);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                measureLabel,
                style: AppTextStyles.style(
                  fontSize: 11,
                  color: AppColors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: slice.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slice.displayLabel,
                      style: AppTextStyles.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$valueText (${pct.toStringAsFixed(2)}%)',
                    style: AppTextStyles.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatValue(double value) {
    return switch (measure) {
      TimesheetGraphMeasure.timeSpent => formatOdooHours(value),
      TimesheetGraphMeasure.timeCosts => value.toStringAsFixed(2),
      TimesheetGraphMeasure.count => value.toInt().toString(),
    };
  }
}

class _WeeklyGroupedBarChart extends StatefulWidget {
  const _WeeklyGroupedBarChart({
    required this.data,
    required this.measure,
  });

  final TimesheetGraphChartData data;
  final TimesheetGraphMeasure measure;

  @override
  State<_WeeklyGroupedBarChart> createState() => _WeeklyGroupedBarChartState();
}

class _WeeklyGroupedBarChartState extends State<_WeeklyGroupedBarChart> {
  final ScrollController _scrollController = ScrollController();

  static const double _yAxisWidth = 42;
  static const double _bottomTitleSpace = _weekAxisBottomSpace;
  static const double _barWidth = 12;
  static const double _barsSpace = 3;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _maxBarsPerGroup(
    List<TimesheetWeekChartGroup> groups,
    List<String> projects,
  ) {
    var maxBars = 0;
    for (final group in groups) {
      final count = projects
          .where((project) => (group.valuesByProject[project] ?? 0) > 0)
          .length;
      if (count > maxBars) maxBars = count;
    }
    return math.max(maxBars, 1);
  }

  double _contentWidth(
    double viewportWidth,
    List<TimesheetWeekChartGroup> groups,
    List<String> projects,
  ) {
    final maxBars = _maxBarsPerGroup(groups, projects);
    final perGroupWidth = maxBars * (_barWidth + _barsSpace) + 28;
    return math.max(viewportWidth, groups.length * perGroupWidth);
  }

  ({List<BarChartRodData> rods, List<String> labels}) _groupedBars(
    TimesheetWeekChartGroup group,
    List<String> projects,
  ) {
    final rods = <BarChartRodData>[];
    final labels = <String>[];

    for (final project in projects) {
      final value = group.valuesByProject[project] ?? 0;
      if (value <= 0) continue;

      labels.add(project);
      rods.add(
        BarChartRodData(
          toY: value,
          width: _barWidth,
          color: widget.data.projectColors[project] ?? AppColors.primary,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(2),
          ),
        ),
      );
    }

    return (rods: rods, labels: labels);
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.data.weekGroups;
    final projects = widget.data.projectLabels;
    if (groups.isEmpty) return const SizedBox.shrink();

    final yMax = _niceMaxY(widget.data.maxValue, widget.measure);
    final yInterval = _yInterval(yMax, widget.measure);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth - _yAxisWidth;
        final contentWidth = _contentWidth(viewportWidth, groups, projects);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OdooHorizontalChartLegend(
              labels: projects,
              colors: widget.data.projectColors,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, chartConstraints) {
                  final chartHeight = chartConstraints.maxHeight;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _yAxisWidth,
                        child: Padding(
                          padding:
                              const EdgeInsets.only(bottom: _bottomTitleSpace),
                          child: _ChartYAxis(
                            yMax: yMax,
                            interval: yInterval,
                            measure: widget.measure,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          primary: false,
                          child: SizedBox(
                            width: contentWidth,
                            height: chartHeight,
                            child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceBetween,
                                  maxY: yMax,
                                  minY: 0,
                                  groupsSpace: 16,
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: yInterval,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: AppColors.border
                                          .withValues(alpha: 0.55),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false),
                                    ),
                                    leftTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: _bottomTitleSpace,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          final i = value.round();
                                          if (i < 0 || i >= groups.length) {
                                            return const SizedBox.shrink();
                                          }
                                          if ((value - i).abs() > 0.01) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: _weekAxisTitle(groups[i]),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: _barChartTouchTooltipData(
                                      getTooltipItem: (group, groupIndex, rod,
                                          rodIndex) {
                                        final weekLabel = _weekTooltipLabel(
                                          groups[group.x.toInt()],
                                        );
                                        final built = _groupedBars(
                                          groups[group.x.toInt()],
                                          projects,
                                        );
                                        final project = rodIndex >= 0 &&
                                                rodIndex < built.labels.length
                                            ? built.labels[rodIndex]
                                            : '';
                                        return BarTooltipItem(
                                          '$weekLabel\n$project\n${_formatAxisValue(rod.toY, widget.measure)}',
                                          _chartTooltipTextStyle(),
                                          textAlign: TextAlign.left,
                                        );
                                      },
                                    ),
                                  ),
                                  barGroups:
                                      List.generate(groups.length, (i) {
                                    final built =
                                        _groupedBars(groups[i], projects);
                                    return BarChartGroupData(
                                      x: i,
                                      barsSpace: _barsSpace,
                                      barRods: built.rods.isEmpty
                                          ? [
                                              BarChartRodData(
                                                toY: 0,
                                                width: _barWidth,
                                                color: Colors.transparent,
                                              ),
                                            ]
                                          : built.rods,
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeeklyMultiLineChart extends StatefulWidget {
  const _WeeklyMultiLineChart({
    required this.data,
    required this.measure,
  });

  final TimesheetGraphChartData data;
  final TimesheetGraphMeasure measure;

  @override
  State<_WeeklyMultiLineChart> createState() => _WeeklyMultiLineChartState();
}

class _WeeklyMultiLineChartState extends State<_WeeklyMultiLineChart> {
  final ScrollController _scrollController = ScrollController();

  static const double _yAxisWidth = 48;
  static const double _bottomTitleSpace = _weekAxisBottomSpace;
  static const double _minPointWidth = 76;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.data.weekGroups;
    if (groups.isEmpty) return const SizedBox.shrink();

    final yMax = _niceMaxY(widget.data.maxValue, widget.measure);
    final yInterval = _yInterval(yMax, widget.measure);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth - _yAxisWidth;
        final contentWidth = math.max(
          viewportWidth,
          groups.length * _minPointWidth + 16,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OdooHorizontalChartLegend(
              labels: widget.data.projectLabels,
              colors: widget.data.projectColors,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, chartConstraints) {
                  final chartHeight = chartConstraints.maxHeight;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _yAxisWidth,
                        child: Padding(
                          padding:
                              const EdgeInsets.only(bottom: _bottomTitleSpace),
                          child: _ChartYAxis(
                            yMax: yMax,
                            interval: yInterval,
                            measure: widget.measure,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          primary: false,
                          child: SizedBox(
                            width: contentWidth,
                            height: chartHeight,
                            child: LineChart(
                              LineChartData(
                              minX: 0,
                              maxX: groups.isEmpty
                                  ? 0
                                  : (groups.length - 1).toDouble(),
                              minY: 0,
                              maxY: yMax,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: yInterval,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color:
                                      AppColors.border.withValues(alpha: 0.6),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: _bottomTitleSpace,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.round();
                                      if (i < 0 || i >= groups.length) {
                                        return const SizedBox.shrink();
                                      }
                                      if ((value - i).abs() > 0.01) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: _weekAxisTitle(groups[i]),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineTouchData: LineTouchData(
                                enabled: true,
                                touchSpotThreshold: 22,
                                touchTooltipData: _lineChartTouchTooltipData(
                                  getTooltipItems: (spots) {
                                    return spots.map((spot) {
                                      if (spot.y <= 0) return null;
                                      final i = spot.x.toInt();
                                      final project = widget
                                          .data.projectLabels[spot.barIndex];
                                      final weekLabel =
                                          i >= 0 && i < groups.length
                                              ? _weekTooltipLabel(groups[i])
                                              : '';
                                      return LineTooltipItem(
                                        '$weekLabel\n$project\n${_formatAxisValue(spot.y, widget.measure)}',
                                        _chartTooltipTextStyle(),
                                        textAlign: TextAlign.left,
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData:
                                  widget.data.projectLabels.map((project) {
                                final color = widget.data.projectColors[
                                        project] ??
                                    AppColors.primary;
                                return LineChartBarData(
                                  spots: List.generate(groups.length, (i) {
                                    return FlSpot(
                                      i.toDouble(),
                                      groups[i].valuesByProject[project] ?? 0,
                                    );
                                  }),
                                  isCurved: true,
                                  curveSmoothness: 0.35,
                                  preventCurveOverShooting: true,
                                  preventCurveOvershootingThreshold: 0,
                                  color: color,
                                  barWidth: 2.5,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, bar, index) =>
                                            FlDotCirclePainter(
                                      radius: 3.5,
                                      color: color,
                                      strokeWidth: 0,
                                    ),
                                  ),
                                  belowBarData: BarAreaData(show: false),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChartYAxis extends StatelessWidget {
  const _ChartYAxis({
    required this.yMax,
    required this.interval,
    required this.measure,
  });

  final double yMax;
  final double interval;
  final TimesheetGraphMeasure measure;

  @override
  Widget build(BuildContext context) {
    final ticks = _yTickValues(yMax, interval);
    if (ticks.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: ticks.reversed.map((value) {
        return Text(
          _formatAxisValue(value, measure),
          style: AppTextStyles.style(
            fontSize: 9,
            color: AppColors.textSecondary,
          ),
        );
      }).toList(),
    );
  }
}

List<double> _yTickValues(double yMax, double interval) {
  if (interval <= 0 || yMax <= 0) return [0];

  final ticks = <double>[];
  for (var value = 0.0; value <= yMax + 0.0001; value += interval) {
    ticks.add(value);
    if (ticks.length >= 7) break;
  }
  return ticks;
}

const double _weekAxisLabelWidth = 72;
const double _weekAxisBottomSpace = 42;
const double _chartTooltipMaxWidth = 240;
const EdgeInsets _chartTooltipPadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 10);

Color _chartTooltipBackgroundColor() =>
    AppColors.black.withValues(alpha: 0.9);

TextStyle _chartTooltipTextStyle() => AppTextStyles.style(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.white,
      height: 1.35,
    );

String _weekTooltipLabel(TimesheetWeekChartGroup group) =>
    'W${group.week} ${group.year}';

LineTouchTooltipData _lineChartTouchTooltipData({
  required GetLineTooltipItems getTooltipItems,
}) {
  return LineTouchTooltipData(
    getTooltipItems: getTooltipItems,
    getTooltipColor: (_) => _chartTooltipBackgroundColor(),
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    maxContentWidth: _chartTooltipMaxWidth,
    tooltipMargin: 8,
    tooltipPadding: _chartTooltipPadding,
    tooltipBorderRadius: BorderRadius.circular(6),
  );
}

BarTouchTooltipData _barChartTouchTooltipData({
  required GetBarTooltipItem getTooltipItem,
}) {
  return BarTouchTooltipData(
    getTooltipItem: getTooltipItem,
    getTooltipColor: (_) => _chartTooltipBackgroundColor(),
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    direction: TooltipDirection.auto,
    maxContentWidth: _chartTooltipMaxWidth,
    tooltipMargin: 8,
    tooltipPadding: _chartTooltipPadding,
    tooltipBorderRadius: BorderRadius.circular(6),
  );
}

Widget _weekAxisTitle(TimesheetWeekChartGroup group) {
  return SizedBox(
    width: _weekAxisLabelWidth,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'W${group.week}',
          textAlign: TextAlign.center,
          maxLines: 1,
          style: AppTextStyles.style(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${group.year}',
          textAlign: TextAlign.center,
          maxLines: 1,
          style: AppTextStyles.style(
            fontSize: 9,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

double _niceMaxY(double max, TimesheetGraphMeasure measure) {
  if (max <= 0) {
    return switch (measure) {
      TimesheetGraphMeasure.timeSpent => 5,
      TimesheetGraphMeasure.timeCosts => 100,
      TimesheetGraphMeasure.count => 5,
    };
  }

  return switch (measure) {
    TimesheetGraphMeasure.timeSpent => _niceHourAxisMax(max),
    TimesheetGraphMeasure.timeCosts => _niceNumberAxisMax(max, step: 100),
    TimesheetGraphMeasure.count => _niceNumberAxisMax(max, step: 5),
  };
}

double _niceHourAxisMax(double max) {
  if (max <= 8) return math.max(1, max.ceilToDouble());
  if (max <= 40) return ((max / 5).ceil()) * 5.0;
  if (max <= 120) return ((max / 10).ceil()) * 10.0;
  if (max <= 500) return ((max / 50).ceil()) * 50.0;
  if (max <= 2000) return ((max / 200).ceil()) * 200.0;
  if (max <= 15000) return ((max / 2000).ceil()) * 2000.0;
  return ((max / 5000).ceil()) * 5000.0;
}

double _niceNumberAxisMax(double max, {required double step}) {
  if (max <= step) return step;
  return ((max / step).ceil()) * step;
}

double _yInterval(double yMax, TimesheetGraphMeasure measure) {
  return switch (measure) {
    TimesheetGraphMeasure.timeSpent => () {
        if (yMax <= 8) return 1.0;
        if (yMax <= 40) return 5.0;
        if (yMax <= 120) return 10.0;
        if (yMax <= 500) return 50.0;
        if (yMax <= 2000) return 200.0;
        if (yMax <= 15000) return 2000.0;
        return 5000.0;
      }(),
    TimesheetGraphMeasure.timeCosts => yMax <= 100
        ? 25.0
        : yMax <= 1000
            ? 100.0
            : 2000.0,
    TimesheetGraphMeasure.count => yMax <= 5 ? 1.0 : 5.0,
  };
}

String _formatAxisValue(double value, TimesheetGraphMeasure measure) {
  return switch (measure) {
    TimesheetGraphMeasure.timeSpent => () {
        if (value >= 10000) {
          return '${(value / 1000).toStringAsFixed(0)}k';
        }
        if (value >= 1000) {
          return '${(value / 1000).toStringAsFixed(1)}k';
        }
        if (value >= 100) return value.round().toString();
        return formatOdooHours(value);
      }(),
    TimesheetGraphMeasure.timeCosts => value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}k'
        : value.toStringAsFixed(0),
    TimesheetGraphMeasure.count => value.toInt().toString(),
  };
}
