import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_logger.dart';
import '../../../data/models/leave_allocation_record.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/approvals_controller.dart';

class AllocationDetailController extends GetxController {
  AllocationDetailController({required this.allocationId});

  final int allocationId;

  final isLoading = true.obs;
  final isActing = false.obs;
  final errorMessage = ''.obs;
  final record = Rxn<LeaveAllocationRecord>();

  LeaveRepository? get _repo {
    final client = Get.find<AuthController>().odooClient;
    if (client == null) return null;
    return LeaveRepository(client);
  }

  @override
  void onInit() {
    super.onInit();
    loadDetail();
  }

  Future<void> loadDetail() async {
    final repo = _repo;
    if (repo == null) {
      errorMessage.value = 'Not connected to server';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final result = await repo.fetchAllocationById(allocationId);
      if (result == null) {
        errorMessage.value = 'Allocation not found';
        record.value = null;
      } else {
        record.value = result;
      }
    } catch (e, st) {
      ApiLogger.error('loadDetail allocation failed', e, st);
      errorMessage.value = 'Failed to load allocation details';
      record.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> approve() async {
    final row = record.value;
    if (row == null || !row.canApprove) return;
    await _act(
      actionLabel: 'approve',
      action: (repo) => repo.approveAllocation(row.id),
    );
  }

  Future<void> refuse() async {
    final row = record.value;
    if (row == null || !row.canRefuse) return;
    await _act(
      actionLabel: 'refuse',
      action: (repo) => repo.refuseAllocation(row.id),
    );
  }

  Future<void> _act({
    required String actionLabel,
    required Future<void> Function(LeaveRepository repo) action,
  }) async {
    final repo = _repo;
    if (repo == null) return;

    isActing.value = true;
    try {
      await action(repo);
      Get.snackbar(
        'Allocations',
        'Allocation ${actionLabel}d successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
      if (Get.isRegistered<ApprovalsController>()) {
        await Get.find<ApprovalsController>().loadAll();
      }
      await loadDetail();
    } catch (e) {
      Get.snackbar(
        'Allocations',
        'Could not $actionLabel allocation',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    } finally {
      isActing.value = false;
    }
  }
}
