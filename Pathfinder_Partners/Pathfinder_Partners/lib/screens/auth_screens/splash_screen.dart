import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/providers/utility_provider/country_list_provider.dart';
import 'package:retail_gpt/screens/auth_screens/login_screen.dart';
import 'package:retail_gpt/screens/home_screen/home_screen.dart';
import 'package:retail_gpt/utils/app_colors.dart';

import '../../local_storage/shared_preference.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = "/splash";

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    _requestStoragePermissions();
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..forward();

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.microtask(() {
      _controller.addStatusListener((status) async {
        if (status == AnimationStatus.completed) {
          String token = await SharedPreference.getToken();
          int userId = await SharedPreference.getUserId();
          String userName = await SharedPreference.getUserName();
          if (token.isEmpty) {
            GetxNavigation().navigateToNextAndRemovePreviousAll(
              LoginScreen.routeName,
            );
          } else {
            CountryListProvider countryListProvider =
                Provider.of<CountryListProvider>(context, listen: false);
            await countryListProvider.getCountryList();
            GetxNavigation().navigateToNextAndRemovePreviousAll(
              HomeScreen.routeName,
            );
          }
        }
      });
    });
  }

  Future<void> _requestStoragePermissions() async {
    if (kIsWeb || kIsWasm) return;
    final storagePermissionStatus = await Permission.storage.status;
    final cameraPermissionStatus = await Permission.camera.status;
    LocationPermission permission = await Geolocator.checkPermission();
    if (!storagePermissionStatus.isGranted) {
      await Permission.storage.request(); // Request read permission
    }
    if (!cameraPermissionStatus.isGranted) {
      await Permission.camera.request(); // Request read permission
    }
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: ClipOval(
                child: Container(
                  width: 150, // Adjusted size for a perfect circle
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white, // Background inside the circle
                  ),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.cover, // Ensures the logo fits well inside
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'RetailGPT',
                  // 'Pathfinder - RetailGPT',
                  textStyle: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                  speed: Duration(milliseconds: 150),
                  cursor: "",
                ),
              ],
              totalRepeatCount: 1,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animation.removeListener(() {});
    super.dispose();
  }
}
