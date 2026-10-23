import 'package:get/get.dart';
import '../data/repositories/order_repository.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/totp_view.dart';
import '../modules/home/views/worksheet_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/delivery_view.dart';
import '../modules/home/views/home_view.dart';
import '../modules/home/views/invoice_view.dart';
import '../modules/home/views/order_create_view.dart';
import '../modules/home/views/order_product_view.dart';
import '../modules/home/views/sale_order_view.dart';
import 'app_routes.dart';

// Placeholder views for future modules
// Remove these once you build each screen
import 'package:flutter/material.dart';

class _PlaceholderView extends StatelessWidget {
  final String title;
  const _PlaceholderView({required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Text(
        '$title\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, color: Colors.grey),
      ),
    ),
  );
}

class AppPages {
  AppPages._();

  static final pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
      transition: Transition.fadeIn,
    ),

    // ── Auth ──────────────────────────────────
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
      transition: Transition.fadeIn,
    ),

    // ── TOTP / 2FA ────────────────────────────
    GetPage(
      name: AppRoutes.totp,
      page: () => const TotpView(),
      transition: Transition.rightToLeft,
    ),

    // ── Dashboard ─────────────────────────────
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: Transition.fadeIn,
    ),

    // ── Tasks ─────────────────────────────────
    GetPage(
      name: AppRoutes.tasks,
      page: () => const _PlaceholderView(title: 'Tasks'),
      // binding: TaskBinding(),
    ),

    // ── Task Detail ───────────────────────────
    GetPage(
      name: AppRoutes.taskDetail,
      page: () => const _PlaceholderView(title: 'Task Detail'),
    ),

    // ── Scheduling ────────────────────────────
    GetPage(
      name: AppRoutes.scheduling,
      page: () => const _PlaceholderView(title: 'Scheduling'),
    ),

    // ── Timesheet ─────────────────────────────
    GetPage(
      name: AppRoutes.timesheet,
      page: () => const _PlaceholderView(title: 'Timesheet'),
    ),

    // ── Report ────────────────────────────────
    GetPage(
      name: AppRoutes.report,
      page: () => const _PlaceholderView(title: 'Reports'),
    ),

    // ── Map ───────────────────────────────────
    GetPage(
      name: AppRoutes.map,
      page: () => const _PlaceholderView(title: 'Map'),
    ),

    // ── Profile ───────────────────────────────
    GetPage(
      name: AppRoutes.profile,
      page: () => const _PlaceholderView(title: 'Profile'),
    ),
    GetPage(
      name: AppRoutes.orderCreate,
      page: () => const OrderCreateView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.orderProducts,
      page: () => const OrderProductsView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.saleOrder,
      page: () => const SaleOrderView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.deliveryList,
      page: () => const DeliveryListView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.invoiceDetail,
      page: () => const InvoiceView(),
      transition: Transition.rightToLeft,
    ),
    // Add these two GetPage entries in the pages list:
    GetPage(
      name: AppRoutes.worksheetList,
      page: () => WorksheetListView(
        fsmOrderId: Get.arguments['fsmOrderId'] as int,
        repository: Get.find<OrderRepository>(),
      ),
    ),
    GetPage(
      name: AppRoutes.worksheetForm,
      page: () => WorksheetFormView(
        recordId: Get.arguments['recordId'] as int?,
        recordName: Get.arguments['recordName'] as String? ?? '',
        fsmOrderId: Get.arguments['fsmOrderId'] as int,
        repository: Get.find<OrderRepository>(),
      ),
    ),
  ];
}