import 'package:get/get.dart';

import '../controllers/allocation_detail_controller.dart';

class AllocationDetailBinding extends Bindings {
  @override
  void dependencies() {
    final id = Get.arguments as int;
    Get.lazyPut(() => AllocationDetailController(allocationId: id));
  }
}
