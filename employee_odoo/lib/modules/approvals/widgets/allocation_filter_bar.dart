import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/approvals_controller.dart';
import '../models/allocation_filters.dart';

/// Search bar + Filters / Group By panel for the Allocations tab, mirroring
/// the Odoo web search (minus Custom Group and Favorites).
class AllocationFilterBar extends GetView<ApprovalsController> {
  const AllocationFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _SearchField()),
              const SizedBox(width: 10),
              const _FilterButton(),
            ],
          ),
          const _ActiveFilterChips(),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final ApprovalsController _controller = Get.find<ApprovalsController>();
  late final TextEditingController _textController;
  late final Worker _syncWorker;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: _controller.allocationSearchQuery.value,
    );
    // Keeps the field in sync when the query is cleared externally
    // ("Clear all" chip) without recreating the field mid-typing.
    _syncWorker = ever<String>(_controller.allocationSearchQuery, (value) {
      if (value != _textController.text) {
        _textController.text = value;
      }
    });
  }

  @override
  void dispose() {
    _syncWorker.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textController,
      onChanged: (v) => _controller.allocationSearchQuery.value = v,
      style: AppTextStyles.style(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search employee or type...',
        hintStyle: AppTextStyles.style(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _textController,
          builder: (_, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: () =>
                      _controller.allocationSearchQuery.value = '',
                ),
        ),
        filled: true,
        fillColor: AppColors.inputFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandBlue),
        ),
      ),
    );
  }
}

class _FilterButton extends GetView<ApprovalsController> {
  const _FilterButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.activeAllocationFilterCount;
      final active = count > 0;
      return GestureDetector(
        onTap: () => _AllocationFilterSheet.show(),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: active ? AppColors.blueGradient : null,
            color: active ? null : AppColors.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? Colors.transparent : AppColors.border,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: active ? AppColors.white : AppColors.textSecondary,
              ),
              if (active)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.brandOrange,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.style(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// Removable facet chips for whatever is currently active — like Odoo's
/// search facets.
class _ActiveFilterChips extends GetView<ApprovalsController> {
  const _ActiveFilterChips();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chips = <({String label, VoidCallback onRemove})>[
        for (final f in controller.allocationStatusFilters)
          (
            label: f.label,
            onRemove: () => controller.toggleAllocationStatusFilter(f),
          ),
        if (controller.allocationCurrentlyValid.value)
          (
            label: 'Currently Valid',
            onRemove: () =>
                controller.allocationCurrentlyValid.value = false,
          ),
        if (controller.allocationMyTeam.value)
          (
            label: 'My Team',
            onRemove: controller.toggleAllocationMyTeam,
          ),
        if (controller.allocationMyDepartment.value)
          (
            label: 'My Department',
            onRemove: controller.toggleAllocationMyDepartment,
          ),
        for (final option in controller.validityStartOptions)
          if (controller.allocationValidityKeys.contains(option.key))
            (
              label: 'Start: ${option.label}',
              onRemove: () =>
                  controller.toggleAllocationValidityKey(option.key),
            ),
        for (final g in controller.allocationGroupBys)
          (
            label: 'Group: ${g.label}',
            onRemove: () => controller.toggleAllocationGroupBy(g),
          ),
      ];

      if (chips.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final chip in chips)
              Container(
                padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: AppColors.brandBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chip.label,
                      style: AppTextStyles.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue,
                      ),
                    ),
                    GestureDetector(
                      onTap: chip.onRemove,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.brandBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            GestureDetector(
              onTap: controller.clearAllocationFilters,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 5,
                ),
                child: Text(
                  'Clear all',
                  style: AppTextStyles.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
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

class _AllocationFilterSheet extends GetView<ApprovalsController> {
  const _AllocationFilterSheet();

  static Future<void> show() {
    final context = Get.context;
    if (context == null) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _AllocationFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Obx(() {
        // Touch the observables so every toggle rebuilds the sheet.
        controller.allocationStatusFilters.length;
        controller.allocationValidityKeys.length;
        controller.allocationGroupBys.length;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filters & Group By',
                      style: AppTextStyles.style(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (controller.activeAllocationFilterCount > 0)
                    GestureDetector(
                      onTap: controller.clearAllocationFilters,
                      child: Text(
                        'Clear all',
                        style: AppTextStyles.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle(Icons.filter_alt_outlined, 'Filters'),
              const SizedBox(height: 8),
              _chipWrap([
                for (final f in AllocationStatusFilter.values)
                  (
                    label: f.label,
                    selected:
                        controller.allocationStatusFilters.contains(f),
                    onTap: () => controller.toggleAllocationStatusFilter(f),
                  ),
              ]),
              const Divider(height: 24),
              _chipWrap([
                (
                  label: 'Currently Valid',
                  selected: controller.allocationCurrentlyValid.value,
                  onTap: () => controller.allocationCurrentlyValid.value =
                      !controller.allocationCurrentlyValid.value,
                ),
              ]),
              const Divider(height: 24),
              _chipWrap([
                (
                  label: 'My Team',
                  selected: controller.allocationMyTeam.value,
                  onTap: controller.toggleAllocationMyTeam,
                ),
                (
                  label: 'My Department',
                  selected: controller.allocationMyDepartment.value,
                  onTap: controller.toggleAllocationMyDepartment,
                ),
              ]),
              const Divider(height: 24),
              Text(
                'Validity Start',
                style: AppTextStyles.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _chipWrap([
                for (final option in controller.validityStartOptions)
                  (
                    label: option.label,
                    selected: controller.allocationValidityKeys
                        .contains(option.key),
                    onTap: () =>
                        controller.toggleAllocationValidityKey(option.key),
                  ),
              ]),
              const SizedBox(height: 20),
              _sectionTitle(Icons.layers_outlined, 'Group By'),
              const SizedBox(height: 8),
              _chipWrap([
                for (final g in AllocationGroupBy.values)
                  (
                    label: g.label,
                    selected: controller.allocationGroupBys.contains(g),
                    onTap: () => controller.toggleAllocationGroupBy(g),
                  ),
              ]),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done',
                  style: AppTextStyles.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandBlue),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTextStyles.style(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _chipWrap(
    List<({String label, bool selected, VoidCallback onTap})> options,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          GestureDetector(
            onTap: option.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: option.selected ? AppColors.blueGradient : null,
                color: option.selected ? null : AppColors.inputFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: option.selected
                      ? Colors.transparent
                      : AppColors.border,
                ),
              ),
              child: Text(
                option.label,
                style: AppTextStyles.style(
                  fontSize: 12,
                  fontWeight:
                      option.selected ? FontWeight.w700 : FontWeight.w500,
                  color: option.selected
                      ? AppColors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
