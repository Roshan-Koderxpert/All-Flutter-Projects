import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_datetime.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../../data/models/leave_allocation_record.dart';
import '../controllers/allocation_detail_controller.dart';
import '../../../core/utils/responsive.dart';

const _green = Color(0xFF3DA93D);

class AllocationDetailView extends GetView<AllocationDetailController> {
  const AllocationDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final title = controller.record.value?.detailTitle ?? 'Allocation';

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppMainAppBar(title: title),
        body: ResponsiveBody(child: _buildBody()),
      );
    });
  }

  Widget _buildBody() {
    return Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brandBlue),
          );
        }

        if (controller.errorMessage.value.isNotEmpty) {
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
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: AppColors.error.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.style(color: AppColors.error),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: controller.loadDetail,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandBlue,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final record = controller.record.value;
        if (record == null) return const SizedBox.shrink();

        return RefreshIndicator(
          color: AppColors.brandBlue,
          backgroundColor: AppColors.white,
          onRefresh: controller.loadDetail,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _ActionBar(record: record),
              const SizedBox(height: 16),
              _MainInfoCard(record: record),
            ],
          ),
        );
      });
  }
}

class _ActionBar extends GetView<AllocationDetailController> {
  const _ActionBar({required this.record});

  final LeaveAllocationRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AllocationStatusBar(state: record.state),
          const SizedBox(height: 16),
          Obx(() {
            final acting = controller.isActing.value;
            final canRefuse = record.canRefuse;
            final canApprove = record.canApprove;

            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: acting || !canRefuse ? null : controller.refuse,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: canRefuse
                          ? AppColors.error
                          : AppColors.textSecondary,
                      side: BorderSide(
                        color: canRefuse
                            ? AppColors.error.withValues(alpha: 0.6)
                            : AppColors.border,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: acting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Refuse'),
                            ],
                          ),
                  ),
                ),
                if (canApprove) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: acting ? null : controller.approve,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _AllocationStatusBar extends StatelessWidget {
  const _AllocationStatusBar({required this.state});

  final LeaveAllocationState state;

  @override
  Widget build(BuildContext context) {
    if (state == LeaveAllocationState.refused) {
      return _StatusStep(
        label: 'Refused',
        active: true,
        isLast: true,
        isError: true,
      );
    }

    return Row(
      children: [
        Expanded(
          child: _StatusStep(
            label: 'To Approve',
            active: state == LeaveAllocationState.toApprove ||
                state == LeaveAllocationState.secondApproval,
            completed: state == LeaveAllocationState.approved,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusStep(
            label: 'Approved',
            active: state == LeaveAllocationState.approved,
            completed: state == LeaveAllocationState.approved,
            isLast: true,
          ),
        ),
      ],
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({
    required this.label,
    required this.active,
    this.completed = false,
    this.isLast = false,
    this.isError = false,
  });

  final String label;
  final bool active;
  final bool completed;
  final bool isLast;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;

    if (isError) {
      bg = AppColors.errorLight;
      fg = AppColors.error;
      border = AppColors.error.withValues(alpha: 0.4);
    } else if (active) {
      bg = AppColors.brandOrange;
      fg = AppColors.white;
      border = AppColors.brandOrange;
    } else if (completed) {
      bg = AppColors.brandBlue.withValues(alpha: 0.1);
      fg = AppColors.brandBlue;
      border = AppColors.brandBlue.withValues(alpha: 0.3);
    } else {
      bg = AppColors.inputFill;
      fg = AppColors.textSecondary;
      border = AppColors.border;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.style(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          color: fg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MainInfoCard extends StatelessWidget {
  const _MainInfoCard({required this.record});

  final LeaveAllocationRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  record.detailTitle,
                  style: AppTextStyles.style(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _FormRow(
            label: 'Time Off Type',
            child: Text(
              record.leaveTypeName,
              style: AppTextStyles.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.brandBlue,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FormRow(
            label: 'Employee',
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.brandBlue,
                  child: Text(
                    record.employeeName.isNotEmpty
                        ? record.employeeName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.style(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record.employeeName.isNotEmpty
                        ? record.employeeName
                        : '—',
                    style: AppTextStyles.style(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FormRow(
            label: 'Allocation Type',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReadOnlyRadioOption(
                  label: 'Regular Allocation',
                  selected: !record.isAccrualAllocation,
                ),
                const SizedBox(height: 6),
                _ReadOnlyRadioOption(
                  label: 'Accrual Allocation',
                  selected: record.isAccrualAllocation,
                ),
              ],
            ),
          ),
          if (record.isAccrualAllocation &&
              record.accrualPlanName != '—') ...[
            const SizedBox(height: 16),
            _FormRow(
              label: 'Accrual Plan',
              child: Text(
                record.accrualPlanName,
                style: AppTextStyles.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _FormRow(
            label: 'Validity Period',
            child: _ValidityPeriodRow(record: record),
          ),
          const SizedBox(height: 16),
          _FormRow(
            label: 'Allocation',
            labelTrailing: Icon(
              Icons.help_outline,
              size: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    record.allocationAmountValue,
                    style: AppTextStyles.style(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandBlue,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Days',
                    style: AppTextStyles.style(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidityPeriodRow extends StatelessWidget {
  const _ValidityPeriodRow({required this.record});

  final LeaveAllocationRecord record;

  @override
  Widget build(BuildContext context) {
    final label = record.validityPeriodLabel;
    if (label == '—') {
      return Text(
        label,
        style: AppTextStyles.style(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (record.dateFrom == null && record.dateTo == null) {
      return Text(
        label,
        style: AppTextStyles.style(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final start = record.dateFrom != null
        ? OdooDateTime.formatDateSlash(record.dateFrom)
        : null;
    final end =
        record.dateTo != null ? OdooDateTime.formatDateSlash(record.dateTo) : null;

    if (start == null) {
      return Text(
        label,
        style: AppTextStyles.style(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          start,
          style: AppTextStyles.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: AppColors.brandBlue.withValues(alpha: 0.7),
        ),
        Text(
          end ?? 'No Limit',
          style: AppTextStyles.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: end == null ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyRadioOption extends StatelessWidget {
  const _ReadOnlyRadioOption({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          size: 18,
          color: selected ? AppColors.brandBlue : AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.style(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.label,
    required this.child,
    this.labelTrailing,
  });

  final String label;
  final Widget child;
  final Widget? labelTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.style(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (labelTrailing != null) ...[
                const SizedBox(width: 4),
                labelTrailing!,
              ],
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
