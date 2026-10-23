import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/attendance_controller.dart';
import '../models/attendance_search_models.dart';

/// Full-height bottom sheet for Filters & Group By (mobile-friendly).
class AttendanceFilterSheet {
  AttendanceFilterSheet._();

  static Future<void> show(BuildContext context) {
    final controller = Get.find<AttendanceController>();
    FocusManager.instance.primaryFocus?.unfocus();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return _SheetContent(scrollController: scrollController);
          },
        ),
      ),
    ).whenComplete(() => controller.panelOpen.value = false);
  }
}

class _SheetContent extends StatefulWidget {
  const _SheetContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Get.find<AttendanceController>().panelOpen.value = true;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AttendanceController>();

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Search options',
                  style: AppTextStyles.style(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  controller.clearAllFilters();
                  Navigator.pop(context);
                },
                child: Text(
                  'Clear all',
                  style: AppTextStyles.style(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_alt_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Filters'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.layers_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Group By'),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _FiltersTab(scrollController: widget.scrollController),
              _GroupByTab(scrollController: widget.scrollController),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Apply',
                  style: AppTextStyles.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FiltersTab extends GetView<AttendanceController> {
  const _FiltersTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _filterItem(AttendancePresetFilter.myAttendances),
        _filterItem(AttendancePresetFilter.myTeam),
        const _SectionDivider(),
        _filterItem(AttendancePresetFilter.atWork),
        _filterItem(AttendancePresetFilter.errors),
        _filterItem(AttendancePresetFilter.autoCheckedOut),
        const _SectionDivider(),
        const _DateFilterSection(),
        const _SectionDivider(),
        _filterItem(AttendancePresetFilter.activeEmployees),
        _filterItem(AttendancePresetFilter.archivedEmployees),
      ],
    );
  }

  Widget _filterItem(AttendancePresetFilter filter) {
    return Obx(() {
      final selected = controller.activeFilters.contains(filter);
      return _OptionTile(
        label: filter.label,
        selected: selected,
        onTap: () => controller.toggleFilter(filter),
      );
    });
  }
}

class _GroupByTab extends GetView<AttendanceController> {
  const _GroupByTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ...AttendanceGroupByField.values.map((field) {
          return Obx(() {
            final selected = controller.selectedGroupByField.value == field;
            return _OptionTile(
              label: field.label,
              selected: selected,
              onTap: () => controller.setGroupByField(field),
            );
          });
        }),
        const _SectionDivider(),
        const _DateGroupBySection(),
        const _SectionDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Add Custom Group',
            style: AppTextStyles.style(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateFilterSection extends GetView<AttendanceController> {
  const _DateFilterSection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expanded = controller.dateFilterMenuExpanded.value;
      final selected = controller.activeDateFilter.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExpandHeader(
            title: 'Date',
            expanded: expanded,
            selected: selected != null,
            onTap: controller.toggleDateFilterMenu,
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                children: [
                  ...controller.recentMonths.map((m) {
                    return _OptionTile(
                      label: m.name,
                      selected: selected?.label == m.name,
                      dense: true,
                      onTap: () => controller.applyMonthDateFilter(
                        m.year,
                        m.month,
                        m.name,
                      ),
                    );
                  }),
                  const _SectionDivider(),
                  ...List.generate(4, (i) {
                    final q = 4 - i;
                    return _OptionTile(
                      label: 'Q$q',
                      selected: selected?.label == 'Q$q',
                      dense: true,
                      onTap: () => controller.applyQuarterDateFilter(
                        DateTime.now().year,
                        q,
                      ),
                    );
                  }),
                  const _SectionDivider(),
                  ...controller.recentYears.map((y) {
                    return _OptionTile(
                      label: y.toString(),
                      selected: selected?.label == y.toString(),
                      dense: true,
                      onTap: () => controller.applyYearDateFilter(y),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _DateGroupBySection extends GetView<AttendanceController> {
  const _DateGroupBySection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expanded = controller.dateGroupByMenuExpanded.value;
      final selectedGran = controller.selectedDateGranularity.value;
      final hasField = controller.selectedGroupByField.value != null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExpandHeader(
            title: 'Date',
            expanded: expanded,
            selected: selectedGran != null && !hasField,
            onTap: controller.toggleDateGroupByMenu,
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                children: AttendanceDateGroupGranularity.values.map((g) {
                  final isSelected = !hasField && selectedGran == g;
                  return _OptionTile(
                    label: g.label,
                    selected: isSelected,
                    highlighted: isSelected,
                    dense: true,
                    onTap: () => controller.setDateGroupGranularity(g),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _ExpandHeader extends StatelessWidget {
  const _ExpandHeader({
    required this.title,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 20, color: AppColors.accent),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.highlighted = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool highlighted;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 10 : 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.style(
                    fontSize: dense ? 14 : 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 22, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: AppColors.border),
    );
  }
}
