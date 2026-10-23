import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_datetime.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/widgets/dashboard_card.dart';

const _red = Color(0xFFDB3F3F);
const _green = Color(0xFF3DA93D);

/// Read-only today summary — check in/out lives on the Home screen.
class AttendanceTodayCard extends GetView<HomeController> {
  const AttendanceTodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => DashboardCard(
        accentColor: AppColors.brandBlue,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brandBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.today_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Today',
                        style: AppTextStyles.style(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: controller.attendanceStatus.value),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'In ${OdooDateTime.formatDateTime(controller.checkInTime.value)} · '
                    'Out ${OdooDateTime.formatDateTime(controller.checkOutTime.value)} · '
                    '${OdooDateTime.formatDurationHhMm(controller.workedHoursToday.value)}',
                    style: AppTextStyles.style(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;

    switch (status) {
      case 'checked_in':
        label = 'On Duty';
        bg = AppColors.brandBlue;
      case 'checked_out':
        label = 'Checked Out';
        bg = _green;
      default:
        label = 'Absent';
        bg = _red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyles.style(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
