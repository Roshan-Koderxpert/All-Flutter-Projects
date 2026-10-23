import 'package:get/get.dart';

import '../../modules/approvals/bindings/allocation_detail_binding.dart';
import '../../modules/approvals/views/allocation_detail_view.dart';
import '../../modules/attendance/bindings/attendance_detail_binding.dart';
import '../../modules/attendance/views/attendance_detail_view.dart';
import '../../modules/auth/bindings/auth_binding.dart';
import '../../modules/auth/bindings/two_factor_binding.dart';
import '../../modules/auth/views/login_view.dart';
import '../../modules/auth/views/two_factor_view.dart';
import '../../modules/directory/bindings/employee_directory_binding.dart';
import '../../modules/directory/controllers/employee_directory_controller.dart';
import '../../modules/directory/views/employee_directory_detail_view.dart';
import '../../modules/directory/views/employee_directory_list_view.dart';
import '../../modules/expense/bindings/expense_binding.dart';
import '../../modules/expense/views/expense_list_view.dart';
import '../../modules/expense/views/expense_detail_view.dart';
import '../../modules/expense/views/expense_report_detail_view.dart';
import '../../modules/home/bindings/home_binding.dart';
import '../../modules/home/views/main_view.dart';
import '../../modules/payslip/bindings/payslip_binding.dart';
import '../../modules/payslip/views/payslip_list_view.dart';
import '../../modules/profile/views/add_account_page.dart';
import '../../modules/profile/views/profile_page.dart';
import '../../modules/settings/views/biometric_lock_view.dart';
import '../../modules/task/bindings/task_binding.dart';
import '../../modules/task/views/task_detail_view.dart';
import '../../modules/task/views/task_list_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = AppRoutes.login;

  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.twoFactor,
      page: () => const TwoFactorView(),
      binding: TwoFactorBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const MainView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfilePage(),
    ),
    GetPage(
      name: AppRoutes.addAccount,
      page: () => const AddAccountPage(),
    ),
    GetPage(
      name: AppRoutes.attendanceDetail,
      page: () => const AttendanceDetailView(),
      binding: AttendanceDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.allocationDetail,
      page: () => const AllocationDetailView(),
      binding: AllocationDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.biometricLock,
      page: () => const BiometricLockView(),
    ),
    GetPage(
      name: AppRoutes.expenseList,
      page: () => const ExpenseListView(),
      binding: ExpenseBinding(),
    ),
    GetPage(
      name: AppRoutes.expenseDetail,
      page: () => const ExpenseDetailView(),
    ),
    GetPage(
      name: AppRoutes.expenseReportDetail,
      page: () => const ExpenseReportDetailView(),
    ),
    GetPage(
      name: AppRoutes.directoryList,
      page: () => const EmployeeDirectoryListView(),
      binding: EmployeeDirectoryBinding(),
    ),
    GetPage(name: AppRoutes.directoryDetail, page: () => const EmployeeDirectoryDetailView()),
    GetPage(
      name: AppRoutes.taskList,
      page: () => const TaskListView(),
      binding: TaskBinding(),
    ),
    GetPage(name: AppRoutes.taskDetail, page: () => const TaskDetailView()),
    GetPage(
      name: AppRoutes.payslipList,
      page: () => const PayslipListView(),
      binding: PayslipBinding(),
    ),
  ];
}
