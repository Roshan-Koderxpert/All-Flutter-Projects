import 'package:get/get.dart';

import '../../approvals/controllers/approvals_controller.dart';
import '../../attendance/controllers/attendance_controller.dart';
import '../../leave/controllers/leave_controller.dart';
import '../../timesheet/controllers/timesheet_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<AttendanceController>(() => AttendanceController());
    Get.lazyPut<LeaveController>(() => LeaveController());
    Get.lazyPut<TimesheetController>(() => TimesheetController());
    Get.lazyPut<ApprovalsController>(() => ApprovalsController());
  }
}
