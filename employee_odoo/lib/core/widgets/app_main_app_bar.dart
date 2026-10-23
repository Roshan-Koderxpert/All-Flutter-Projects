import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_back_button.dart';

class AppMainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppMainAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leadingColor,
  });

  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Color? leadingColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return AppBar(
      title: Text(
        title,
        style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
      ),
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: automaticallyImplyLeading && canPop
          ? AppBackButton(color: leadingColor ?? Colors.white)
          : null,
      backgroundColor: AppColors.brandBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      actions: actions,
    );
  }
}
