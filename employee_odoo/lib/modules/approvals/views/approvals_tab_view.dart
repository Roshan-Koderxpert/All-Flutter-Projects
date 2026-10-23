import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/expense_approval_item.dart';
import '../../../data/models/leave_record.dart';
import '../controllers/approvals_controller.dart';
import '../widgets/allocation_filter_bar.dart';
import '../widgets/allocations_odoo_list.dart';

const _green = Color(0xFF3DA93D);

class ApprovalsTabView extends GetView<ApprovalsController> {
  const ApprovalsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _ApprovalsModeSwitcher(),
          ),
          const _ApprovalsSummaryStrip(),
          Expanded(
            child: Obx(() {
              final keys = controller.visibleApprovalTabs;
              final index =
                  controller.innerTabIndex.value.clamp(0, keys.length - 1);
              switch (keys[index]) {
                case 'expenses':
                  return const _ExpenseApprovalsTab();
                case 'allocations':
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AllocationFilterBar(),
                      Expanded(child: AllocationsOdooList()),
                    ],
                  );
                default:
                  return const _TimeOffApprovalsTab();
              }
            }),
          ),
        ],
      ),
    );
  }
}

class _ApprovalsModeSwitcher extends GetView<ApprovalsController> {
  const _ApprovalsModeSwitcher();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final keys = controller.visibleApprovalTabs;
      final idx = controller.innerTabIndex.value.clamp(0, keys.length - 1);
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < keys.length; i++)
              _ModeTab(
                label: switch (keys[i]) {
                  'expenses' => 'Expenses',
                  'allocations' => 'Allocations',
                  _ => 'Time Off',
                },
                icon: switch (keys[i]) {
                  'expenses' => Icons.receipt_long_outlined,
                  'allocations' => Icons.account_balance_wallet_outlined,
                  _ => Icons.event_available_rounded,
                },
                selected: idx == i,
                // Three tabs share the width that two used to have.
                compact: keys.length > 2,
                onTap: () => controller.setInnerTab(i),
              ),
          ],
        ),
      );
    });
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// Tightens the type and spacing when more than two tabs share the row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: 10,
            horizontal: compact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.blueGradient : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          // Shrinks to fit instead of overflowing: "Allocations" at three
          // tabs on a 320dp screen is wider than the third it is given.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: compact ? 16 : 18,
                  color: selected ? AppColors.white : AppColors.textSecondary,
                ),
                SizedBox(width: compact ? 5 : 6),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: AppTextStyles.style(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalsSummaryStrip extends GetView<ApprovalsController> {
  const _ApprovalsSummaryStrip();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final keys = controller.visibleApprovalTabs;
      final tab = keys[controller.innerTabIndex.value.clamp(0, keys.length - 1)];
      final isAllTimeOff = controller.timeOffTabIndex.value == 0;
      final isAllExpenses = controller.expenseTabIndex.value == 0;

      final (count, label, isLoading) = switch (tab) {
        'allocations' => (
            controller.visibleAllocations.length,
            'Allocations',
            controller.isLoadingAllocations.value,
          ),
        'expenses' => isAllExpenses
            ? (
                controller.allExpenses.length,
                'All expenses',
                controller.isLoadingAllExpenses.value,
              )
            : (
                controller.pendingExpenses.length,
                'Pending expenses',
                controller.isLoadingPendingExpenses.value,
              ),
        _ => isAllTimeOff
            ? (
                controller.allLeaves.length,
                'All time off',
                controller.isLoadingAllLeaves.value,
              )
            : (
                controller.pendingLeaves.length,
                'Pending time off',
                controller.isLoadingLeaves.value,
              ),
      };
      final isTimeOff = tab == 'timeoff';

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.brandBlue.withValues(alpha: 0.08),
                AppColors.brandOrange.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brandBlue.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isTimeOff
                      ? Icons.pending_actions_rounded
                      : Icons.fact_check_outlined,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.style(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'request' : 'requests'}',
                      style: AppTextStyles.style(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandBlue,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _TimeOffApprovalsTab extends GetView<ApprovalsController> {
  const _TimeOffApprovalsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TimeOffSubTabs(),
        Expanded(
          child: Obx(() {
            if (controller.timeOffTabIndex.value == 0) {
              return const _AllTimeOffList();
            }
            return const _ToApproveList();
          }),
        ),
      ],
    );
  }
}

class _TimeOffSubTabs extends GetView<ApprovalsController> {
  const _TimeOffSubTabs();

  static const _labels = ['All Time Off', 'To Approve'];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedIndex = controller.timeOffTabIndex.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        // Scrolls rather than overflowing if a label plus its count badge is
        // wider than the screen.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
          children: List.generate(_labels.length, (index) {
            final selected = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => controller.setTimeOffTab(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.blueGradient : null,
                    color: selected ? null : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: selected ? 0.15 : 0.06,
                        ),
                        blurRadius: selected ? 6 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _labels[index],
                        style: AppTextStyles.style(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (index == 1 &&
                          controller.pendingLeaves.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.white.withValues(alpha: 0.25)
                                : AppColors.brandOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${controller.pendingLeaves.length}',
                            style: AppTextStyles.style(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
          ),
        ),
      );
    });
  }
}

class _AllTimeOffList extends GetView<ApprovalsController> {
  const _AllTimeOffList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingAllLeaves.value && controller.allLeaves.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brandBlue),
        );
      }

      if (controller.errorMessageAllLeaves.value.isNotEmpty &&
          controller.allLeaves.isEmpty) {
        return _ApprovalsEmptyState(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          title: 'Could not load time off',
          message: controller.errorMessageAllLeaves.value,
          actionLabel: 'Retry',
          onAction: controller.loadAllTimeOff,
        );
      }

      if (controller.allLeaves.isEmpty) {
        return _ApprovalsEmptyState(
          icon: Icons.event_busy_rounded,
          iconColor: AppColors.brandBlue,
          title: 'No time off records',
          message: 'No time off requests were found.',
        );
      }

      return RefreshIndicator(
        color: AppColors.brandBlue,
        backgroundColor: AppColors.white,
        onRefresh: controller.loadAllTimeOff,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: controller.allLeaves.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final leave = controller.allLeaves[index];
            // Managers can act on pending rows from the management list too,
            // matching Odoo; everything else is display-only.
            return _ApprovalCard(
              leave: leave,
              showActions: leave.state.isPending,
            );
          },
        ),
      );
    });
  }
}

class _ToApproveList extends GetView<ApprovalsController> {
  const _ToApproveList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingLeaves.value &&
          controller.pendingLeaves.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brandBlue),
        );
      }

      if (controller.errorMessageLeaves.value.isNotEmpty &&
          controller.pendingLeaves.isEmpty) {
        return _ApprovalsEmptyState(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          title: 'Could not load approvals',
          message: controller.errorMessageLeaves.value,
          actionLabel: 'Retry',
          onAction: controller.loadPendingApprovals,
        );
      }

      if (controller.pendingLeaves.isEmpty) {
        return _ApprovalsEmptyState(
          icon: Icons.check_circle_outline_rounded,
          iconColor: AppColors.brandBlue,
          title: 'All caught up',
          message: 'No pending time off requests need your approval.',
        );
      }

      return RefreshIndicator(
        color: AppColors.brandBlue,
        backgroundColor: AppColors.white,
        onRefresh: controller.loadPendingApprovals,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: controller.pendingLeaves.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final leave = controller.pendingLeaves[index];
            return _ApprovalCard(leave: leave);
          },
        ),
      );
    });
  }
}

class _ApprovalCard extends GetView<ApprovalsController> {
  const _ApprovalCard({required this.leave, this.showActions = true});

  final LeaveRecord leave;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: switch (leave.state) {
                  LeaveState.approved => _green,
                  LeaveState.refused ||
                  LeaveState.cancelled =>
                    AppColors.error,
                  _ => AppColors.brandOrange,
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.brandBlue,
                            child: Text(
                              leave.employeeName.isNotEmpty
                                  ? leave.employeeName[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.style(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  leave.employeeName.isNotEmpty
                                      ? leave.employeeName
                                      : 'Employee',
                                  style: AppTextStyles.style(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  leave.leaveTypeName,
                                  style: AppTextStyles.style(
                                    fontSize: 13,
                                    color: AppColors.brandBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StateBadge(state: leave.state),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.brandBlue.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              leave.dateRangeLabel,
                              style: AppTextStyles.style(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              leave.durationLabel,
                              style: AppTextStyles.style(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (leave.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            leave.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.style(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      Obx(() {
                        final attachments =
                            controller.attachmentsFor(leave.id);
                        if (attachments.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final downloadingId =
                            controller.downloadingAttachmentId.value;
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: attachments.map((a) {
                              final downloading = downloadingId == a.id;
                              return GestureDetector(
                                onTap: downloading
                                    ? null
                                    : () =>
                                        controller.previewAttachment(a),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandBlue
                                        .withValues(alpha: 0.08),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.brandBlue
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (downloading)
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.brandBlue,
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.attach_file_rounded,
                                          size: 13,
                                          color: AppColors.brandBlue,
                                        ),
                                      const SizedBox(width: 5),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 140,
                                        ),
                                        child: Text(
                                          a.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.style(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.brandBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                      if (showActions) ...[
                      const SizedBox(height: 14),
                      Obx(() {
                        final acting = controller.isActing.value;
                        final isThisCard = acting &&
                            controller.actingLeaveId.value == leave.id;
                        final action = controller.actingLeaveAction.value;
                        final refusingThis = isThisCard && action == 'refuse';
                        final approvingThis = isThisCard && action == 'approve';
                        return Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isThisCard
                                    ? null
                                    : () => controller.refuse(leave),
                                icon: refusingThis
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.error,
                                        ),
                                      )
                                    : const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Refuse'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: BorderSide(
                                    color: AppColors.error.withValues(alpha: 0.6),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: isThisCard
                                    ? null
                                    : () => controller.approve(leave),
                                icon: approvingThis
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Approve'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: AppColors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final LeaveState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      LeaveState.approved => (AppColors.brandBlue, AppColors.white),
      LeaveState.refused || LeaveState.cancelled => (
          AppColors.error,
          AppColors.white,
        ),
      LeaveState.toApprove || LeaveState.secondApproval => (
          AppColors.brandOrange,
          AppColors.white,
        ),
      _ => (Colors.grey.shade400, AppColors.white),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        state.label,
        style: AppTextStyles.style(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _ApprovalsEmptyState extends StatelessWidget {
  const _ApprovalsEmptyState({
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

/// Expenses approval area. Odoo 19 has no expense reports, so approval acts on
/// the `hr.expense` record itself: submitted -> approved / refused.
class _ExpenseApprovalsTab extends GetView<ApprovalsController> {
  const _ExpenseApprovalsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ExpenseSubTabs(),
        Expanded(
          child: Obx(() {
            if (controller.expenseTabIndex.value == 0) {
              return const _AllExpensesList();
            }
            return const _ExpensesToApproveList();
          }),
        ),
      ],
    );
  }
}

class _ExpenseSubTabs extends GetView<ApprovalsController> {
  const _ExpenseSubTabs();

  static const _labels = ['All Expenses', 'To Approve'];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedIndex = controller.expenseTabIndex.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        // Scrolls rather than overflowing if a label plus its count badge is
        // wider than the screen.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
          children: List.generate(_labels.length, (index) {
            final selected = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => controller.setExpenseTab(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.blueGradient : null,
                    color: selected ? null : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: selected ? 0.15 : 0.06),
                        blurRadius: selected ? 6 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _labels[index],
                        style: AppTextStyles.style(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (index == 1 &&
                          controller.pendingExpenses.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.white.withValues(alpha: 0.25)
                                : AppColors.brandOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${controller.pendingExpenses.length}',
                            style: AppTextStyles.style(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
          ),
        ),
      );
    });
  }
}

class _AllExpensesList extends GetView<ApprovalsController> {
  const _AllExpensesList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingAllExpenses.value &&
          controller.allExpenses.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brandBlue),
        );
      }
      if (controller.errorMessageAllExpenses.value.isNotEmpty &&
          controller.allExpenses.isEmpty) {
        return _ApprovalsEmptyState(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          title: 'Could not load expenses',
          message: controller.errorMessageAllExpenses.value,
          actionLabel: 'Retry',
          onAction: controller.loadAllExpenses,
        );
      }
      if (controller.allExpenses.isEmpty) {
        return _ApprovalsEmptyState(
          icon: Icons.receipt_long_outlined,
          iconColor: AppColors.brandBlue,
          title: 'No expenses',
          message: 'No expense records were found.',
        );
      }

      return RefreshIndicator(
        color: AppColors.brandBlue,
        backgroundColor: AppColors.white,
        onRefresh: controller.loadAllExpenses,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: controller.allExpenses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final record = controller.allExpenses[index];
            // Only a submitted expense is actionable, as in Odoo.
            return _ExpenseApprovalCard(
              record: record,
              showActions: record.isPending,
            );
          },
        ),
      );
    });
  }
}

class _ExpensesToApproveList extends GetView<ApprovalsController> {
  const _ExpensesToApproveList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingPendingExpenses.value &&
          controller.pendingExpenses.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brandBlue),
        );
      }
      if (controller.errorMessagePendingExpenses.value.isNotEmpty &&
          controller.pendingExpenses.isEmpty) {
        return _ApprovalsEmptyState(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          title: 'Could not load approvals',
          message: controller.errorMessagePendingExpenses.value,
          actionLabel: 'Retry',
          onAction: controller.loadPendingExpenses,
        );
      }
      if (controller.pendingExpenses.isEmpty) {
        return _ApprovalsEmptyState(
          icon: Icons.check_circle_outline_rounded,
          iconColor: AppColors.brandBlue,
          title: 'All caught up',
          message: 'No expenses need your approval.',
        );
      }

      return RefreshIndicator(
        color: AppColors.brandBlue,
        backgroundColor: AppColors.white,
        onRefresh: controller.loadPendingExpenses,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: controller.pendingExpenses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _ExpenseApprovalCard(record: controller.pendingExpenses[index]),
        ),
      );
    });
  }
}

class _ExpenseApprovalCard extends GetView<ApprovalsController> {
  const _ExpenseApprovalCard({required this.record, this.showActions = true});

  final ExpenseApprovalItem record;
  final bool showActions;

  Color get _accent {
    if (record.isSettled) return _green;
    if (record.isRefused) return AppColors.error;
    return AppColors.brandOrange;
  }

  Future<void> _confirmRefuse(BuildContext context) async {
    // The dialog owns its own controller (see _RefuseReasonDialog). Disposing
    // one here would kill it while the dismiss animation is still painting the
    // field, which throws "TextEditingController was used after being
    // disposed" and corrupts the overlay for that frame.
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RefuseReasonDialog(),
    );
    if (reason == null) return;
    await controller.refuseExpense(record, reason);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: _accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.brandBlue,
                            child: Text(
                              record.employeeName.isNotEmpty
                                  ? record.employeeName[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.style(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.employeeName.isNotEmpty
                                      ? record.employeeName
                                      : 'Employee',
                                  style: AppTextStyles.style(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  record.categoryName.isNotEmpty
                                      ? record.categoryName
                                      : record.lineCount != null
                                          ? '${record.lineCount} expense'
                                              '${record.lineCount == 1 ? '' : 's'}'
                                          : 'Expense',
                                  style: AppTextStyles.style(
                                    fontSize: 13,
                                    color: AppColors.brandBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          _ExpenseStateBadge(item: record),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        record.title,
                        style: AppTextStyles.style(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.brandBlue.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              record.date == null
                                  ? '—'
                                  : '${record.date!.day.toString().padLeft(2, '0')}/'
                                      '${record.date!.month.toString().padLeft(2, '0')}/'
                                      '${record.date!.year}',
                              style: AppTextStyles.style(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.brandBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              record.amount.toStringAsFixed(2),
                              style: AppTextStyles.style(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showActions) ...[
                        const SizedBox(height: 14),
                        Obx(() {
                          final acting = controller.isActing.value;
                          final isThisCard = acting &&
                              controller.actingExpenseId.value == record.id;
                          final action = controller.actingExpenseAction.value;
                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  // Only this card reacts; other rows stay
                                  // untouched while an action runs.
                                  onPressed: isThisCard
                                      ? null
                                      : () => _confirmRefuse(context),
                                  icon: isThisCard && action == 'refuse'
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.error,
                                          ),
                                        )
                                      : const Icon(Icons.close_rounded,
                                          size: 16),
                                  label: const Text('Refuse'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: BorderSide(
                                      color: AppColors.error
                                          .withValues(alpha: 0.6),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: isThisCard
                                      ? null
                                      : () =>
                                          controller.approveExpense(record),
                                  icon: isThisCard && action == 'approve'
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded,
                                          size: 16),
                                  label: const Text('Approve'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _green,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseStateBadge extends StatelessWidget {
  const _ExpenseStateBadge({required this.item});

  final ExpenseApprovalItem item;

  @override
  Widget build(BuildContext context) {
    final bg = item.isSettled
        ? _green
        : item.isRefused
            ? AppColors.error
            : item.isPending
                ? AppColors.brandOrange
                : Colors.grey.shade400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        // Odoo's own translated label for this state.
        item.stateLabel,
        style: AppTextStyles.style(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
    );
  }
}

/// Asks for a refusal reason.
///
/// Stateful so the [TextEditingController] lives exactly as long as the dialog
/// does: created with the State and disposed by it *after* the route is gone,
/// which is what makes the close animation safe.
class _RefuseReasonDialog extends StatefulWidget {
  const _RefuseReasonDialog();

  @override
  State<_RefuseReasonDialog> createState() => _RefuseReasonDialogState();
}

class _RefuseReasonDialogState extends State<_RefuseReasonDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Refuse expense'),
      content: TextField(
        controller: _reasonController,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Reason for refusal',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () =>
              Navigator.pop(context, _reasonController.text.trim()),
          child: const Text('Refuse'),
        ),
      ],
    );
  }
}
