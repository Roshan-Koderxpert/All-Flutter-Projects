import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/leave_record.dart';
import '../controllers/leave_controller.dart';
import '../views/leave_detail_view.dart';

class LeaveRequestList extends GetView<LeaveController> {
  const LeaveRequestList({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.errorMessage.value.isNotEmpty &&
          controller.filteredRequests.isEmpty &&
          controller.allRequests.isEmpty) {
        return _scrollableEmpty(
          _LeaveEmptyState(
            icon: Icons.error_outline_rounded,
            iconColor: AppColors.error,
            title: 'Could not load leave requests',
            message: controller.errorMessage.value,
            actionLabel: 'Retry',
            onAction: controller.loadLeaves,
          ),
        );
      }

      if (controller.filteredRequests.isEmpty) {
        return _scrollableEmpty(
          _LeaveEmptyState(
            icon: Icons.beach_access_outlined,
            iconColor: AppColors.brandOrange,
            title: controller.allRequests.isEmpty
                ? 'No leave requests yet'
                : 'No requests in this filter',
            message: controller.allRequests.isEmpty
                ? 'Tap Apply Leave to submit your first time off request.'
                : 'Try a different filter to see more requests.',
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: controller.filteredRequests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _LeaveRequestCard(
            record: controller.filteredRequests[index],
          );
        },
      );
    });
  }

  Widget _scrollableEmpty(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: child,
            ),
          ],
        );
      },
    );
  }
}

class _LeaveRequestCard extends GetView<LeaveController> {
  const _LeaveRequestCard({required this.record});

  final LeaveRecord record;

  Color get _accentColor => switch (record.state) {
        LeaveState.approved => AppColors.brandBlue,
        LeaveState.refused || LeaveState.cancelled => AppColors.error,
        LeaveState.toApprove || LeaveState.secondApproval => AppColors.brandOrange,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => LeaveDetailView(record: record)),
      child: Container(
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
                Container(width: 4, color: _accentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.leaveTypeName,
                                style: AppTextStyles.style(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _StatusBadge(state: record.state),
                          ],
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
                                record.dateRangeLabel,
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
                                color: AppColors.brandBlue.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                record.durationLabel,
                                style: AppTextStyles.style(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (record.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            record.description,
                            style: AppTextStyles.style(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (controller.canCancel(record)) ...[
                          const SizedBox(height: 10),
                          Obx(() {
                            final isCancelling =
                                controller.cancellingLeaveId.value ==
                                    record.id;
                            return Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: isCancelling
                                    ? null
                                    : () async {
                                        final ok = await _confirmCancel(
                                          context,
                                        );
                                        if (!ok) return;
                                        await controller.cancelLeaveRequest(
                                          record,
                                          successMessage:
                                              'Leave request cancelled from list',
                                        );
                                      },
                                icon: isCancelling
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.cancel_outlined,
                                        size: 16,
                                      ),
                                label: const Text('Cancel'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(
                                    color: AppColors.error,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
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
      ),
    );
  }

  Future<bool> _confirmCancel(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel leave request?'),
        content: const Text('This request will be cancelled in Odoo.'),
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        state.label,
        style: AppTextStyles.style(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _LeaveEmptyState extends StatelessWidget {
  const _LeaveEmptyState({
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
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
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
