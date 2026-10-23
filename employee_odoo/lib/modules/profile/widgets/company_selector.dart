import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/controllers/auth_controller.dart';

class CompanySelector extends GetView<AuthController> {
  const CompanySelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final companies = controller.companies;
      final selected = controller.selectedCompanyIds;

      if (companies.isEmpty) {
        return Text(
          'No companies available',
          style: AppTextStyles.style(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        );
      }

      return Column(
        children: companies.map((company) {
          final id = company['id'] as int;
          final name = company['name']?.toString() ?? 'Company';
          final isSelected = selected.contains(id);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.toggleCompanySelection(id),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: AppTextStyles.style(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}
