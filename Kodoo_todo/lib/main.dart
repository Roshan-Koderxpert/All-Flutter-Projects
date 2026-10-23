// lib/main.dart
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/pages/splash/splash_screen.dart';
import 'app/routes/app_routes.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt < 33) {
      await Permission.storage.request();
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: 60, fontWeight: FontWeight.w800),
      displayMedium: base.displayMedium?.copyWith(fontSize: 48, fontWeight: FontWeight.w800),
      displaySmall: base.displaySmall?.copyWith(fontSize: 38, fontWeight: FontWeight.w700),
      headlineLarge: base.headlineLarge?.copyWith(fontSize: 34, fontWeight: FontWeight.w800),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontSize: 23, fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
      titleSmall: base.titleSmall?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodySmall: base.bodySmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      labelMedium: base.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
      labelSmall: base.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E4A6B)),
    );

    final textTheme = _buildTextTheme(GoogleFonts.nunitoSansTextTheme(base.textTheme));

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Kodoo To-Do",
      theme: base.copyWith(
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          titleTextStyle: textTheme.titleLarge?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      home: const SplashScreen(),
      getPages: AppRoutes.pages,
    );
  }
}