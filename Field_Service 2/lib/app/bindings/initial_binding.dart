import 'package:get/get.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/network_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/theme_service.dart';
import '../core/services/translation_service.dart';
import '../data/providers/api_provider.dart';
import '../data/repositories/chatter_repository.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<StorageService>(
      StorageService(),
      permanent: true,
    );

    Get.put<NetworkService>(
      NetworkService(),
      permanent: true,
    );

    Get.put<ThemeService>(
      ThemeService(Get.find<StorageService>()),
      permanent: true,
    );

    Get.put<ConnectivityService>(
      ConnectivityService(),
      permanent: true,
    );

    // TranslationService must be registered before any screen renders.
    // It registers English immediately and rehydrates any cached language.
    Get.put<TranslationService>(
      TranslationService(),
      permanent: true,
    );

    Get.put<ApiProvider>(
      ApiProvider(
        Get.find<NetworkService>(),
        Get.find<StorageService>(),
      ),
      permanent: true,
    );

    Get.put<ChatterRepository>(
      ChatterRepository(Get.find<ApiProvider>()),
      permanent: true,
    );

    final storage = Get.find<StorageService>();
    final network = Get.find<NetworkService>();
    if (storage.isLoggedIn && storage.serverUrl.isNotEmpty) {
      network.restoreBaseUrlFromStorage(storage.serverUrl);
      if (storage.sessionId.isNotEmpty) {
        network.setSessionId(storage.sessionId);
      }
    }
  }
}
