import 'package:get/get.dart';
import '../controllers/employee_directory_controller.dart';

class EmployeeDirectoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmployeeDirectoryController>(() => EmployeeDirectoryController());
  }
}