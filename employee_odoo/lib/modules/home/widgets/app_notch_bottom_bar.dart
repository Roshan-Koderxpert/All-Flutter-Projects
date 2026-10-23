import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/asset_icon.dart';

class AppNotchBottomBar extends StatelessWidget {
  const AppNotchBottomBar({
    super.key,
    required this.controller,
    required this.tabKeys,
    required this.onTap,
  });

  final NotchBottomBarController controller;

  /// Ordered tab keys to render (from MainController.visibleTabKeys).
  final List<String> tabKeys;
  final ValueChanged<int> onTap;

  static const _inactiveColor = Color(0xFF94A3B8);
  static const _activeColor = Colors.white;
  static const _iconSize = 24.0;

  /// Gap between the bar and the bottom edge of the screen.
  ///
  /// iOS reports a 34pt home-indicator inset where Android reports 0 (button
  /// nav) or ~24 (gesture nav). Adding that inset on top of the bar's own 14pt
  /// margin left the bar floating well clear of the bottom edge on iPhone, so
  /// iOS drops the inset and sits the bar against the edge — the internal
  /// margin still keeps it off the home indicator. Android keeps its original
  /// `inset + 12` and is therefore unchanged.
  static double _bottomGap(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) return 0;
    return MediaQuery.paddingOf(context).bottom + 12;
  }

  /// Total vertical space the bar occupies (for body bottom padding).
  static double totalHeight(BuildContext context) =>
      50 + 28 + 8 + _bottomGap(context);

  /// Width the notch bar paints itself at.
  ///
  /// The package caps itself at its `bottomBarWidth` (default 500) whenever the
  /// screen is wider than 500 and pins that to the left edge, which stranded a
  /// half-width bar in the corner on an iPad. Feeding it the real screen width
  /// makes it span the display like the rest of the tablet layout. Phones are
  /// narrower than 500, where the package uses the screen width anyway, so
  /// nothing changes for them.
  static double _barWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _bottomGap(context)),
      child: _bar(context),
    );
  }

  Widget _bar(BuildContext context) => AnimatedNotchBottomBar(
        bottomBarWidth: _barWidth(context),
        notchBottomBarController: controller,
        onTap: onTap,
        kIconSize: _iconSize,
        kBottomRadius: 24,
        color: AppColors.white,
        notchColor: const Color(0xFF1D5884),
        showLabel: true,
        showShadow: true,
        elevation: 10,
        shadowElevation: 6,
        durationInMilliSeconds: 350,
        bottomBarHeight: 50,
        removeMargins: false,
        circleMargin: 8,
        maxLine: 1,
        textOverflow: TextOverflow.ellipsis,
        itemLabelStyle: AppTextStyles.style(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _inactiveColor,
        ),
        bottomBarItems: _buildItems(),
      );

  List<BottomBarItem> _buildItems() => tabKeys.map(_itemForKey).toList();

  BottomBarItem _itemForKey(String key) {
    const inactiveStyle = _inactiveColor;
    const activeStyle = _activeColor;
    const inactiveIconSize = 22.0;
    const activeIconSize = _iconSize;

    String asset;
    IconData inactiveFallback;
    IconData activeFallback;
    String label;
    switch (key) {
      case 'attendance':
        asset = AppIcon.attendance;
        inactiveFallback = Icons.fingerprint_outlined;
        activeFallback = Icons.fingerprint_rounded;
        label = 'Attendance';
        break;
      case 'leave':
        asset = AppIcon.leaves;
        inactiveFallback = Icons.event_busy_outlined;
        activeFallback = Icons.event_available_rounded;
        label = 'Leaves';
        break;
      case 'timesheet':
        asset = AppIcon.timesheet;
        inactiveFallback = Icons.schedule_outlined;
        activeFallback = Icons.schedule_rounded;
        label = 'Timesheets';
        break;
      case 'approvals':
        asset = AppIcon.approval;
        inactiveFallback = Icons.approval_outlined;
        activeFallback = Icons.approval_rounded;
        label = 'Approvals';
        break;
      case 'home':
      default:
        asset = AppIcon.home;
        inactiveFallback = Icons.home_outlined;
        activeFallback = Icons.home_rounded;
        label = 'Home';
        break;
    }

    return BottomBarItem(
      inActiveItem: _inactiveAssetIcon(
        asset,
        inactiveFallback,
        inactiveIconSize,
        inactiveStyle,
      ),
      activeItem: _activeAssetIcon(
        asset,
        activeFallback,
        activeIconSize,
        activeStyle,
      ),
      itemLabel: label,
    );
  }

  static Widget _inactiveAssetIcon(
    String assetPath,
    IconData fallback,
    double size,
    Color color,
  ) {
    return Center(
      child: AssetIcon(
        assetPath: assetPath,
        fallback: fallback,
        size: size,
        color: color,
      ),
    );
  }

  static Widget _activeAssetIcon(
    String assetPath,
    IconData fallback,
    double size,
    Color color,
  ) {
    return AssetIcon(
      assetPath: assetPath,
      fallback: fallback,
      size: size,
      color: color,
    );
  }
}
