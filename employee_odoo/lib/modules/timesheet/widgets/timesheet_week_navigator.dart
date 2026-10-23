import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/timesheet_controller.dart';

class TimesheetWeekNavigator extends StatelessWidget {
  const TimesheetWeekNavigator({super.key, required this.controller});

  final TimesheetController controller;

  @override
  Widget build(BuildContext context) {
    final start = controller.weekStart.value;
    final end = controller.weekEnd;
    final label = '${_fmtShort(start)} – ${_fmtShort(end)}, ${end.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _NavIconButton(
            icon: Icons.chevron_left_rounded,
            onPressed: controller.previousWeek,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Week',
              style: AppTextStyles.style(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.brandBlue,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: controller.goToCurrentWeek,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandOrange,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              'Today',
              style: AppTextStyles.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _NavIconButton(
            icon: Icons.chevron_right_rounded,
            onPressed: controller.nextWeek,
          ),
        ],
      ),
    );
  }

  String _fmtShort(DateTime d) {
    return '${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: AppColors.brandBlue),
        ),
      ),
    );
  }
}
