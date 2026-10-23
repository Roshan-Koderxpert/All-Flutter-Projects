import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Init GetStorage (lightweight offline key-value store)
  await GetStorage.init();

  final box = GetStorage();
  final languageCode = box.read<String>('selected_language_code') ?? 'en_US';
  final themeMode = box.read<String>('theme_mode') ?? 'light';

  runApp(FSMApp(
    languageCode: languageCode,
    initialThemeMode: themeMode,
  ));
}