import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'storage_service.dart';

class ThemeService extends GetxService {
  ThemeService(this._storage);

  final StorageService _storage;

  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;

  @override
  void onInit() {
    super.onInit();
    final saved = _storage.themeMode;
    themeMode.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    Get.changeThemeMode(themeMode.value);
  }

  bool get isDark => themeMode.value == ThemeMode.dark;

  Future<void> setDark(bool enabled) async {
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    Get.changeThemeMode(themeMode.value);
    await _storage.saveThemeMode(enabled ? 'dark' : 'light');
  }
}
