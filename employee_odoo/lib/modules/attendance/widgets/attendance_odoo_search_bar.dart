import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/attendance_controller.dart';
import '../models/attendance_search_models.dart';
import 'attendance_filter_sheet.dart';

class AttendanceOdooSearchBar extends GetView<AttendanceController> {
  const AttendanceOdooSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 22,
              color: AppColors.brandBlue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(
                () {
                  final _ = controller.searchQuery.value;
                  final hasChips = controller.searchChips.isNotEmpty;
                  if (hasChips) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...controller.searchChips.map(_chip),
                          SizedBox(
                            width: 160,
                            child: _searchField(),
                          ),
                        ],
                      ),
                    );
                  }
                  return _searchField();
                },
              ),
            ),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.border,
            ),
            GestureDetector(
              onTap: () => AttendanceFilterSheet.show(context),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(
                  Icons.tune_rounded,
                  color: AppColors.brandOrange,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: controller.searchController,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.style(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        hintText: 'Search attendance...',
        hintStyle: AppTextStyles.style(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _chip(AttendanceSearchChip chip) {
    final isGroupBy = chip.kind == 'groupBy';
    final icon = isGroupBy
        ? Icons.layers_outlined
        : chip.kind == 'dateFilter'
            ? Icons.calendar_today_outlined
            : Icons.filter_alt_outlined;

    final iconColor =
        isGroupBy ? AppColors.brandOrange : AppColors.brandBlue;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            chip.label,
            style: AppTextStyles.style(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => controller.removeChip(chip),
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: iconColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
