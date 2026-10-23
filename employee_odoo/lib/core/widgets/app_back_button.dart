import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import 'asset_icon.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.color,
    this.onPressed,
    this.size = 22,
  });

  final Color? color;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      icon: AssetIcon(
        assetPath: AppIcon.back,
        fallback: Icons.arrow_back_ios_new_rounded,
        size: size,
        color: color,
      ),
    );
  }
}
