import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'chatter_sheet.dart';

class ChatterFab extends StatelessWidget {
  const ChatterFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.brandBlue,
      onPressed: () => showChatterSheet(context),
      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
    );
  }
}