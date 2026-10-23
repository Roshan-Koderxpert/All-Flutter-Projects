import 'package:flutter/material.dart';
import '../utils/navigation_helper.dart';
import '../core/assets.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final dynamic title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBackPressed;
  final double elevation;
  final IconData? backIcon;
  final Color? backIconColor;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    this.title,
    this.actions,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
    this.onBackPressed,
    this.elevation = 0,
    this.backIcon = Icons.arrow_back,
    this.backIconColor = Colors.black,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Handle both String and Widget for title
    Widget? titleWidget;
    if (title != null) {
      if (title is String) {
        titleWidget = Text(
          title,
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'NunitoSans',
          ),
        );
      } else if (title is Widget) {
        titleWidget = title;
      }
    }

    return AppBar(
      elevation: elevation,
      shadowColor: Colors.transparent,
      title: titleWidget,
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor ?? Colors.white,
      surfaceTintColor: Colors.white,
      scrolledUnderElevation: 0.0,
      forceMaterialTransparency: false,
      automaticallyImplyLeading: false,
      leading: automaticallyImplyLeading
          ? IconButton(
        icon: Image.asset(AppIcon.back, color: Colors.black,
        height: 24,
          width: 24,
        ),
        onPressed: onBackPressed ?? NavigationHelper.safeBack,
      )
          : null,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
  );
}