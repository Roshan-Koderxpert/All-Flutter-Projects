import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/assets.dart';
import '../theme/text_styles.dart';


class FsmBottomNavBar extends StatelessWidget {
  const FsmBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _iconWellSize = 45;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    // On iOS the system already reserves space for the home indicator.
    // We add a small extra pad only when there is no system inset (Android).
    final extraBottom = bottomInset > 0 ? 0.0 : 4.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkSurface2 : AppColors.divider, width: 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, bottomInset + extraBottom),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                assetPath: AppImage.icons.order,
                label: AppStrings.navOrder,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                assetPath: AppImage.navMap,
                label: AppStrings.navMap,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
            ),
            Expanded(
              child: _NavItem(
                assetPath: AppImage.icons.myProfile,
                label: AppStrings.navMyProfile,
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ),
          ],
        ),
      ),
    );

  }
}



class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.assetPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String assetPath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: FsmBottomNavBar._iconWellSize,
            height: FsmBottomNavBar._iconWellSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.primary : (isDark ? AppColors.darkSurface : AppColors.primarySurface),            ),
            alignment: Alignment.center,
            child: Image.asset(
              assetPath,
              width: FsmBottomNavBar._iconSize,
              height: FsmBottomNavBar._iconSize,
              fit: BoxFit.contain,
              color: selected ? AppColors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              fontSize: 13,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

