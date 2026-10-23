import 'package:get/get.dart';
import '../../../data/models/payslip_record.dart';
import '../../../data/repositories/payslip_repository.dart';
import '../../../core/utils/api_logger.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_controller.dart';

enum PayslipModuleStatus { loading, available, unavailable, error, noEmployee }

class PayslipController extends GetxController {
  late final PayslipRepository _repo;

  final payslips = <PayslipRecord>[].obs;
  final status = PayslipModuleStatus.loading.obs;
  final isViewingAll = false.obs;
  // Separate trackers so tapping preview doesn't light up the download
  // button's spinner (and vice versa) — each button only reacts to its
  // own id.
  final downloadingId = RxnInt();
  final previewingId = RxnInt();
  @override
  void onInit() {
    super.onInit();
    final client = Get.find<AuthController>().odooClient;
    _repo = PayslipRepository(client!);
  }

  int? get _employeeId {
    // Employee mode: scope to the employee from login, never the shared user.
    final scoped = Get.find<AuthController>().scopedEmployeeId;
    if (scoped != null) return scoped;
    if (Get.isRegistered<HomeController>()) {
      return Get.find<HomeController>().employeeId.value;
    }
    return null;
  }

  Future<void> loadAll() async {
    status.value = PayslipModuleStatus.loading;
    ApiLogger.info('PayslipController.loadAll: start');

    int? empId = _employeeId;
    ApiLogger.info('PayslipController.loadAll: HomeController employeeId=$empId '
        '(HomeController registered=${Get.isRegistered<HomeController>()})');

    if (empId == null) {
      final userId = Get.find<AuthController>().activeAccount.value?.userId;
      if (userId == null) {
        ApiLogger.error('PayslipController.loadAll: no logged-in userId available for fallback lookup');
        status.value = PayslipModuleStatus.noEmployee;
        return;
      }
      // HomeController may not be registered yet, or its own employee
      // lookup may have failed for this account — resolve it
      // independently rather than sitting on the loading spinner forever.
      ApiLogger.info('PayslipController.loadAll: employeeId missing, trying repository fallback for userId=$userId');
      empId = await _repo.fetchCurrentEmployeeId(userId: userId);
      ApiLogger.info('PayslipController.loadAll: fallback employeeId=$empId');
    }

    if (empId == null) {
      ApiLogger.error('PayslipController.loadAll: could not resolve any employee record for the logged-in user — aborting');
      status.value = PayslipModuleStatus.error;
      return;
    }


    try {
      final userId = Get.find<AuthController>().activeAccount.value?.userId;
      final canViewAll = userId != null && await _repo.hasAllPayslipsAccess(userId: userId);
      ApiLogger.info('PayslipController.loadAll: hasAllPayslipsAccess=$canViewAll');
      isViewingAll.value = canViewAll;

      // Scope to whatever company is currently selected in the app's own
      // company switcher — matches what the web browser shows, instead of
      // silently pulling payslips from every company the user can access.
      final companyIds = Get.find<AuthController>().selectedCompanyIds.toList();
      ApiLogger.info('PayslipController.loadAll: selectedCompanyIds=$companyIds');

      payslips.value = canViewAll
          ? await _repo.fetchAll(allowedCompanyIds: companyIds)
          : await _repo.fetchMine(empId, allowedCompanyIds: companyIds);
      ApiLogger.info('PayslipController.loadAll: loaded ${payslips.length} payslip(s)');
      status.value = PayslipModuleStatus.available;
    } on PayslipModuleUnavailable {
      ApiLogger.error('PayslipController.loadAll: hr.payslip model unavailable on this server');
      status.value = PayslipModuleStatus.unavailable;
    } catch (e, st) {
      ApiLogger.error('PayslipController.loadAll failed', e, st);
      status.value = PayslipModuleStatus.error;
    }
  }

  /// Returns the PDF bytes on success, or null on failure (a snackbar is
  /// already shown from here so callers don't need to duplicate error UI).
// new
  Future<List<int>?> _fetchBytes(PayslipRecord payslip) async {
    final auth = Get.find<AuthController>();
    final account = auth.activeAccount.value;
    if (account?.sessionId == null) {
      Get.snackbar('Not signed in', 'Please log in again to download payslips',
          snackPosition: SnackPosition.BOTTOM);
      return null;
    }

    try {
      return await _repo.downloadPdf(
        baseUrl: account!.url,
        sessionId: account.sessionId!,
        payslipId: payslip.id,
      );
    } on PayslipDownloadException catch (e) {
      Get.snackbar('Download failed', e.message, snackPosition: SnackPosition.BOTTOM);
      return null;
    }
  }

  /// For the download button — tracks its own id in downloadingId.
  Future<List<int>?> downloadPayslip(PayslipRecord payslip) async {
    downloadingId.value = payslip.id;
    try {
      return await _fetchBytes(payslip);
    } finally {
      downloadingId.value = null;
    }
  }

  /// For the eye/preview button — tracks its own id in previewingId,
  /// completely independent of downloadingId.
  Future<List<int>?> previewPayslip(PayslipRecord payslip) async {
    previewingId.value = payslip.id;
    try {
      return await _fetchBytes(payslip);
    } finally {
      previewingId.value = null;
    }
  }

}