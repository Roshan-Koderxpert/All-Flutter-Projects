import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/leave_record.dart';
import '../controllers/leave_controller.dart';
import '../../../core/utils/responsive.dart';

class LeaveDetailView extends GetView<LeaveController> {
  const LeaveDetailView({super.key, required this.record});

  final LeaveRecord record;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Leave Details',
          style: AppTextStyles.style(
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.brandBlue,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: ResponsiveBody(child: Obx(() {
        final latest = _latestRecordOrFallback(record);
        final canCancel = controller.canCancel(latest);
        final isCancelling = controller.cancellingLeaveId.value == latest.id;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          latest.leaveTypeName,
                          style: AppTextStyles.style(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _StatusBadge(state: latest.state),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Date Range', value: latest.dateRangeLabel),
                  _InfoRow(label: 'Duration', value: latest.durationLabel),
                  if (latest.employeeName.isNotEmpty)
                    _InfoRow(label: 'Employee', value: latest.employeeName),
                  _InfoRow(label: 'Request ID', value: '#${latest.id}'),
                  if (latest.description.isNotEmpty)
                    _InfoRow(label: 'Reason', value: latest.description),
                ],
              ),
            ),
            if (canCancel) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: isCancelling
                    ? null
                    : () async {
                        final ok = await _confirmCancel(context);
                        if (!ok) return;
                        final cancelled = await controller.cancelLeaveRequest(latest);
                        if (cancelled && context.mounted) {
                          Navigator.of(context).maybePop();
                        }
                      },
                icon: isCancelling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel Request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        );
      })),
    );
  }

  LeaveRecord _latestRecordOrFallback(LeaveRecord fallback) {
    for (final item in controller.allRequests) {
      if (item.id == fallback.id) return item;
    }
    return fallback;
  }

  Future<bool> _confirmCancel(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel leave request?'),
        content: const Text(
          'This will cancel your draft/pending request in Odoo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: AppTextStyles.style(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final LeaveState state;

  @override
  Widget build(BuildContext context) {
    final bg = switch (state) {
      LeaveState.approved => AppColors.brandBlue,
      LeaveState.refused || LeaveState.cancelled => AppColors.error,
      LeaveState.toApprove || LeaveState.secondApproval => AppColors.brandOrange,
      _ => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        state.label,
        style: AppTextStyles.style(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}
