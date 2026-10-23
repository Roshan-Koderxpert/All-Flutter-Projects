import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/leave_allocation_record.dart';
import '../controllers/allocation_detail_controller.dart';
import '../controllers/approvals_controller.dart';
import '../models/allocation_filters.dart';
import '../views/allocation_detail_view.dart';

const _green = Color(0xFF3DA93D);

class AllocationTableLayout {
  AllocationTableLayout._();

  static const colEmployee = 132.0;
  static const colLeaveType = 120.0;
  static const colAmount = 68.0;
  static const colAllocType = 100.0;
  static const colAccrual = 108.0;
  static const colStatus = 112.0;
  static const colActions = 184.0;
  static const colGap = 10.0;
  static const cellPaddingH = 12.0;

  static const tableWidth =
      colEmployee +
      colLeaveType +
      colAmount +
      colAllocType +
      colAccrual +
      colStatus +
      colActions +
      colGap * 6;

  static double get scrollContentWidth => tableWidth + cellPaddingH * 2;
}

/// Shared 7-column row — keeps header and data rows aligned.
class _AllocationTableRow extends StatelessWidget {
  const _AllocationTableRow({
    required this.employee,
    required this.leaveType,
    required this.amount,
    required this.allocType,
    required this.accrual,
    required this.status,
    required this.actions,
  });

  final Widget employee;
  final Widget leaveType;
  final Widget amount;
  final Widget allocType;
  final Widget accrual;
  final Widget status;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cell(AllocationTableLayout.colEmployee, employee),
        _gap,
        _cell(AllocationTableLayout.colLeaveType, leaveType),
        _gap,
        _cell(AllocationTableLayout.colAmount, amount),
        _gap,
        _cell(AllocationTableLayout.colAllocType, allocType),
        _gap,
        _cell(AllocationTableLayout.colAccrual, accrual),
        _gap,
        _cell(AllocationTableLayout.colStatus, status),
        _gap,
        _cell(AllocationTableLayout.colActions, actions),
      ],
    );
  }

  static const _gap = SizedBox(width: AllocationTableLayout.colGap);

  static Widget _cell(double width, Widget child) {
    return SizedBox(
      width: width,
      child: ClipRect(child: child),
    );
  }
}

class AllocationsOdooList extends GetView<ApprovalsController> {
  const AllocationsOdooList({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingAllocations.value &&
          controller.allocations.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brandBlue),
        );
      }

      if (controller.errorMessageAllocations.value.isNotEmpty &&
          controller.allocations.isEmpty) {
        return _AllocationsEmptyState(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          title: 'Could not load allocations',
          message: controller.errorMessageAllocations.value,
          actionLabel: 'Retry',
          onAction: controller.loadAllocations,
        );
      }

      if (controller.allocations.isEmpty) {
        return const _AllocationsEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: AppColors.brandBlue,
          title: 'No allocations',
          message: 'Leave allocations will appear here when available.',
        );
      }

      final entries = controller.allocationEntries;
      if (entries.isEmpty) {
        return _AllocationsEmptyState(
          icon: Icons.search_off_rounded,
          iconColor: AppColors.brandBlue,
          title: 'No matches',
          message: 'No allocations match your search or filters.',
          actionLabel: 'Clear filters',
          onAction: controller.clearAllocationFilters,
        );
      }

      return RefreshIndicator(
        color: AppColors.brandBlue,
        backgroundColor: AppColors.white,
        onRefresh: controller.loadAllocations,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final minWidth = AllocationTableLayout.scrollContentWidth;
                    final tableWidth = minWidth > constraints.maxWidth
                        ? minWidth
                        : constraints.maxWidth;

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _TableHeader(),
                            ...entries.map(
                              (entry) => entry.isHeader
                                  ? _GroupHeaderRow(entry: entry)
                                  : _AllocationRow(row: entry.record!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _AllocationsEmptyState extends StatelessWidget {
  const _AllocationsEmptyState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: iconColor.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.style(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.style(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableDivider extends StatelessWidget {
  const _TableDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.border.withValues(alpha: 0.6),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AllocationTableLayout.cellPaddingH,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: _AllocationTableRow(
        employee: _headerLabel('Employee'),
        leaveType: _headerLabel('Time Off Type'),
        amount: _headerLabel('Amount'),
        allocType: _headerLabel('Allocation Type'),
        accrual: _headerLabel('Accrual Plan'),
        status: _headerLabel('Status'),
        actions: _headerLabel('Actions'),
      ),
    );
  }

  static Widget _headerLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.style(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.brandBlue,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Group section header — bold label with record count, indented per
/// nesting level, like Odoo's grouped list rows.
class _GroupHeaderRow extends StatelessWidget {
  const _GroupHeaderRow({required this.entry});

  final AllocationListEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: AllocationTableLayout.cellPaddingH + entry.level * 18.0,
        right: AllocationTableLayout.cellPaddingH,
        top: 10,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(
          alpha: entry.level == 0 ? 1.0 : 0.55,
        ),
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.brandBlue.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              entry.label ?? '',
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${entry.count}',
              style: AppTextStyles.style(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.brandBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends GetView<ApprovalsController> {
  const _AllocationRow({required this.row});

  final LeaveAllocationRecord row;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _TableDivider(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openAllocationDetail(row.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AllocationTableLayout.cellPaddingH,
                vertical: 12,
              ),
              child: _AllocationTableRow(
                employee: _DataText(
                  row.employeeName.isNotEmpty ? row.employeeName : '—',
                  bold: true,
                ),
                leaveType: _DataText(
                  row.leaveTypeName,
                  color: AppColors.brandBlue,
                ),
                amount: _DataText(row.amountLabel, bold: true),
                allocType: _DataText(row.allocationType),
                accrual: _DataText(row.accrualPlanName),
                status: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusChip(state: row.state),
                ),
                actions: _ActionButtons(row: row),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DataText extends StatelessWidget {
  const _DataText(
    this.text, {
    this.bold = false,
    this.color,
  });

  final String text;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.style(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        color: color ?? AppColors.textPrimary,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final LeaveAllocationState state;

  Color get _bg => switch (state) {
        LeaveAllocationState.toApprove ||
        LeaveAllocationState.secondApproval =>
          AppColors.brandOrange,
        LeaveAllocationState.approved => AppColors.brandBlue,
        LeaveAllocationState.refused => AppColors.error,
        LeaveAllocationState.draft => Colors.grey.shade400,
        _ => Colors.grey.shade400,
      };

  Color get _fg => AppColors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        state.label,
        style: AppTextStyles.style(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _fg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ActionButtons extends GetView<ApprovalsController> {
  const _ActionButtons({required this.row});

  final LeaveAllocationRecord row;

  static const _buttonGap = 8.0;
  static const _buttonHeight = 34.0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final acting = controller.isActing.value &&
          controller.actingAllocationId.value == row.id;
      final globalActing = controller.isActing.value;
      final canRefuse = row.canRefuse;
      final canApprove = row.canApprove;

      if (!canRefuse && !canApprove) {
        return Text(
          '—',
          textAlign: TextAlign.center,
          style: AppTextStyles.style(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        );
      }

      final showBoth = canRefuse && canApprove;
      final buttonWidth = showBoth
          ? (AllocationTableLayout.colActions - _buttonGap) / 2
          : AllocationTableLayout.colActions;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canRefuse)
            SizedBox(
              width: buttonWidth,
              height: _buttonHeight,
              child: OutlinedButton(
                onPressed: (globalActing && !acting) || !canRefuse
                    ? null
                    : () => controller.refuseAllocation(row),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: AppTextStyles.style(fontSize: 11),
                ),
                child: acting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Refuse'),
              ),
            ),
          if (showBoth) const SizedBox(width: _buttonGap),
          if (canApprove)
            SizedBox(
              width: buttonWidth,
              height: _buttonHeight,
              child: FilledButton(
                onPressed: globalActing && !acting
                    ? null
                    : () => controller.approveAllocation(row),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: _green,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: AppTextStyles.style(fontSize: 11),
                ),
                child: acting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Approve'),
              ),
            ),
        ],
      );
    });
  }
}

void _openAllocationDetail(int allocationId) {
  Get.to(
    () => const AllocationDetailView(),
    binding: BindingsBuilder(
      () {
        Get.lazyPut(
          () => AllocationDetailController(allocationId: allocationId),
        );
      },
    ),
  );
}
