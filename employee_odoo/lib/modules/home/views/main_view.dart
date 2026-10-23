import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bar_profile_button.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../../core/widgets/biometric_app_guard.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../approvals/views/approvals_tab_view.dart';
import '../../attendance/views/attendance_tab_view.dart';
import '../../auth/controllers/auth_controller.dart';
// import '../../chat/widgets/chatter_fab.dart'; // temporarily disabled, see floatingActionButton below
import '../../leave/views/leave_tab_view.dart';
import '../../timesheet/views/timesheet_tab_view.dart';
import '../controllers/main_controller.dart';
import '../widgets/app_notch_bottom_bar.dart';
import 'home_dashboard_view.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Only compact the main shell when this route owns the keyboard (not modal sheets).
    final isMainRouteCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final compactForKeyboard = keyboardOpen && isMainRouteCurrent;
    final bottomClearance = compactForKeyboard
        ? 0.0
        : AppNotchBottomBar.totalHeight(context) + 8;
    final auth = Get.find<AuthController>();
    return Obx(
          () {
        final tabKeys = controller.visibleTabKeys;
        final children = tabKeys.map<Widget>((key) {
          switch (key) {
            case 'attendance':
              return const AttendanceTabView();
            case 'leave':
              return const LeaveTabView();
            case 'timesheet':
              return const TimesheetTabView();
            case 'approvals':
              return const ApprovalsTabView();
            case 'home':
            default:
              return const HomeDashboardView();
          }
        }).toList();

        final selectedIndex = controller.currentIndex.value.clamp(
          0,
          children.length - 1,
        );
        final isSwitchingAccount =
            auth.isSwitchingAccount.value && auth.isLoggedIn.value;

        return BiometricAppGuard(
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: isSwitchingAccount,
                child: Scaffold(
                  backgroundColor: AppColors.background,
                  extendBody: true,
                  resizeToAvoidBottomInset: true,
                  appBar: selectedIndex == 0
                      ? null
                      : AppMainAppBar(
                    title: controller.currentTitle,
                    automaticallyImplyLeading: false,
                    actions: _buildAppBarActions(selectedIndex),
                  ),
                  body: Padding(
                    padding: EdgeInsets.only(bottom: bottomClearance),
                    child: IndexedStack(
                      index: selectedIndex,
                      children: children,
                    ),
                  ),
                  bottomNavigationBar: AppNotchBottomBar(
                    key: const ValueKey('main_notch_bottom_bar'),
                    controller: controller.notchBarController,
                    tabKeys: tabKeys,
                    onTap: controller.changeTab,
                  ),
                  // Chat is a full-user feature — hidden for employee sign-in.
                  // Temporarily disabled on the home screen (chip requested
                  // by product — do not delete, just keep commented out).
                  // floatingActionButton:
                  //     (selectedIndex == 0 && !controller.isEmployeeMode)
                  //         ? const ChatterFab()
                  //         : null,
                  floatingActionButton: null,
                ),
              ),
              if (isSwitchingAccount)
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.background,
                    child: Center(
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.brandBlue,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions(int index) {
    return const [NotificationBell(), AppBarProfileButton()];
  }
}