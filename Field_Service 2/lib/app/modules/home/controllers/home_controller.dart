import 'package:get/get.dart';

import '../../../core/services/storage_service.dart';
import '../../../routes/app_routes.dart';

class HomeController extends GetxController {
  final StorageService _storage;

  HomeController(this._storage);

  /// Bottom navigation: 0 Order, 1 Master Data, 2 My Profile
  final selectedTab = 0.obs;

  String get username => _storage.username;
  String get role => _storage.userRole;
  String get dbName => _storage.selectedDb;

  void selectTab(int index) {
    if (index < 0 || index > 2) return;
    selectedTab.value = index;
  }

  Future<void> logout() async {
    await _storage.clearSession();
    Get.offAllNamed(AppRoutes.login);
  }
}
