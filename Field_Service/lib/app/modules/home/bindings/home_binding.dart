import 'package:get/get.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/order_repository.dart';
import '../controllers/home_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/profile_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OrderRepository>(
      () => OrderRepository(
        Get.find<ApiProvider>(),
        Get.find<ConnectivityService>(),
        Get.find<NetworkService>(),
      ),
    );
    Get.lazyPut<OrderController>(
      () => OrderController(Get.find<OrderRepository>()),
    );
    Get.lazyPut<HomeController>(
      () => HomeController(Get.find<StorageService>()),
    );
    Get.lazyPut<AuthRepository>(
          () => AuthRepository(
        Get.find<ApiProvider>(),
        Get.find<StorageService>(),
        Get.find<NetworkService>(),
        Get.find<ConnectivityService>(),
      ),
    );
    Get.lazyPut<ProfileController>(
          () => ProfileController(Get.find<AuthRepository>()),
    );
  }
}
