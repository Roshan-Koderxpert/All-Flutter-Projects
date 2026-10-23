import 'package:get/get.dart';

import '../controllers/attendance_detail_controller.dart';

class AttendanceDetailBinding extends Bindings {
  @override
  void dependencies() {
    final id = Get.arguments as int;
    Get.lazyPut(() => AttendanceDetailController(recordId: id));
  }
}
