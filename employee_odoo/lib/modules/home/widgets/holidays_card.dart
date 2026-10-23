import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/home_controller.dart';
import 'dashboard_card.dart';

class HolidaysCard extends GetView<HomeController> {
  const HolidaysCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        if (controller.upcomingHolidays.isEmpty) {
          return const SizedBox.shrink();
        }

        return DashboardCard(
          accentColor: AppColors.brandOrange,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.orangeGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Upcoming Holidays',
                    style: AppTextStyles.style(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...controller.upcomingHolidays.asMap().entries.map(
                (entry) {
                  final isEven = entry.key.isEven;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: (isEven ? AppColors.brandBlue : AppColors.brandOrange)
                            .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isEven ? AppColors.brandBlue : AppColors.brandOrange)
                              .withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 18,
                            color: isEven
                                ? AppColors.brandBlue
                                : AppColors.brandOrange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: AppTextStyles.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
