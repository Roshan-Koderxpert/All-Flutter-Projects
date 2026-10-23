import 'package:get/get.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // ApiProvider is registered in [InitialBinding].

    Get.lazyPut<AuthRepository>(
          () => AuthRepository(
        Get.find<ApiProvider>(),
        Get.find<StorageService>(),
        Get.find<NetworkService>(),
        Get.find<ConnectivityService>(),
      ),
    );

    // AuthController depends on AuthRepository
    Get.lazyPut<AuthController>(
          () => AuthController(Get.find<AuthRepository>()),
    );
  }
}