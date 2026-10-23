import 'package:get/get.dart';
import '../routes/app_routes.dart';
import 'login_controller.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _start();
  }

  Future<void> _start() async {
    final authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : Get.put(AuthController());

    await authController.tryAutoLogin();

    final targetRoute = authController.isLoggedIn.value ? AppRoutes.home : AppRoutes.login;
    Get.offAllNamed(targetRoute);
  }
}
