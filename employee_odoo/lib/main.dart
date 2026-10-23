import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/local/auth_storage.dart';
import 'data/services/notification_service.dart';
import 'modules/auth/controllers/auth_controller.dart';
import 'modules/notifications/controllers/notification_controller.dart';
import 'modules/settings/utils/biometric_helper.dart';
import 'modules/splash/views/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Re-enable once GoogleService-Info.plist / Firebase setup is finalized
// await Firebase.initializeApp();
  await GetStorage.init();
  FlutterForegroundTask.initCommunicationPort();
  await Get.putAsync(() => NotificationService().init());
  Get.put(NotificationController());

  InitialBinding().dependencies();

  var initialRoute = AppRoutes.login;
  if (await AuthStorage.isLoggedIn()) {
    final auth = Get.find<AuthController>();
    final restored = await auth.tryAutoLogin(navigate: false);
    if (restored) {
      final biometricEnabled = await BiometricHelper.isBiometricEnabled();
      initialRoute =
          biometricEnabled ? AppRoutes.biometricLock : AppRoutes.home;
    }
  }

  runApp(EmployeeOdooApp(initialRoute: initialRoute));
}

class EmployeeOdooApp extends StatelessWidget {
  const EmployeeOdooApp({super.key, required this.initialRoute});

  /// Where the splash video hands off to once it finishes — already
  /// resolved above from the saved session, before the video ever plays.
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: SplashView(nextRoute: initialRoute),
      getPages: AppPages.routes,
      defaultTransition: Transition.cupertino,
    );
  }
}
