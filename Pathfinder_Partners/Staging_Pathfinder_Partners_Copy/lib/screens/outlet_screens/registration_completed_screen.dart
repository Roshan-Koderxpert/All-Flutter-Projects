import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/Icons/SVG/svg_icons.dart';
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/providers/home_screen/home_screen_provider.dart';
import 'package:retail_gpt/utils/app_colors.dart';

class RegistrationCompletedScreen extends StatelessWidget {
  static const routeName = "/registration-completed";

  const RegistrationCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 20,
          children: [
            SvgPicture.string(SvgIcons.successImage),
            // Successfully subscribe for free listing
            Text(
              "Outlet Successfully Registered",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: ElevatedButton(
                onPressed: () async {
                  HomeScreenProvider homeScreenProvider =
                      Provider.of<HomeScreenProvider>(context, listen: false);
                  await homeScreenProvider.getMonthlyData();
                  await homeScreenProvider.getYearlyData();
                  GetxNavigation().goBack();
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(double.infinity, 45),
                ),
                child: Text(
                  "Finish",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
