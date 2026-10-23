import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:retail_gpt/utils/app_colors.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      height: screenHeight,
      width: screenWidth,
      color: AppColors.primaryColor.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          height: 50,
          width: 50,
          color: Colors.transparent,
          child: LoadingIndicator(
            indicatorType: Indicator.lineScale,
            colors: [AppColors.primaryColor],
            strokeWidth: 1,
            backgroundColor: Colors.transparent,
            pathBackgroundColor: AppColors.primaryColor,
          ),
        ),
      ),
    );
  }
}
