import 'package:field_service/app/modules/home/views/profile_tab_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';

import '../../../core/widgets/fsm_bottom_nav_bar.dart';
import '../controllers/home_controller.dart';
import 'map_tab_view.dart';
import 'order_tab_view.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(
      () => Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
          toolbarHeight: 20,
          backgroundColor: AppColors.primary,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: AppColors.primary,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        body: IndexedStack(
          sizing: StackFit.expand,
          index: controller.selectedTab.value,
          children: [
            _buildOrderTab(),
            _buildMapTab(),
            _buildProfileTab(),
          ],
        ),
        bottomNavigationBar: FsmBottomNavBar(
          currentIndex: controller.selectedTab.value,
          onTap: controller.selectTab,
        ),
      ),
    );
  }

  Widget _buildOrderTab() {
    return const OrderTabView();
  }

  Widget _buildMapTab() {
    return const MapTabView();
  }
  Widget _buildProfileTab() {
    return const ProfileTabView();
  }

}
