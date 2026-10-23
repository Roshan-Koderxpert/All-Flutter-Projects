import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/api_logger.dart';
import '../../../data/models/leave_allocation_record.dart';
import '../../../data/models/leave_record.dart';
import '../../../data/models/expense_approval_item.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../expense/views/attachment_preview_view.dart';
import '../../expense/views/pdf_preview_view.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/controllers/main_controller.dart';
import '../models/allocation_filters.dart';

class ApprovalsController extends GetxController {
  final AuthController _auth = Get.find<AuthController>();
  final HomeController _home = Get.find<HomeController>();

  final isLoadingLeaves = false.obs;
  final isLoadingAllocations = false.obs;
  final isActing = false.obs;
  final actingAllocationId = 0.obs;
  final actingLeaveId = 0.obs;
  final actingLeaveAction = ''.obs; // 'approve' | 'refuse' while acting
  final errorMessageLeaves = ''.obs;
  final errorMessageAllocations = ''.obs;
  final pendingLeaves = <LeaveRecord>[].obs;
  final allocations = <LeaveAllocationRecord>[].obs;
  final innerTabIndex = 0.obs;

  // Time Off sub-tabs: 0 = All Time Off (Odoo management list), 1 = To Approve.
  final timeOffTabIndex = 0.obs;
  final isLoadingAllLeaves = false.obs;
  final errorMessageAllLeaves = ''.obs;
  final allLeaves = <LeaveRecord>[].obs;

  // ---- Expenses tab (Odoo 19: approval happens on hr.expense itself) ----
  // Sub-tabs: 0 = All Expenses, 1 = To Approve, mirroring Time Off.
  final expenseTabIndex = 0.obs;
  final isLoadingAllExpenses = false.obs;
  final isLoadingPendingExpenses = false.obs;
  final errorMessageAllExpenses = ''.obs;
  final errorMessagePendingExpenses = ''.obs;
  final allExpenses = <ExpenseApprovalItem>[].obs;
  final pendingExpenses = <ExpenseApprovalItem>[].obs;
  // Per-record so only the tapped button spins, never the whole list.
  final actingExpenseId = 0.obs;
  final actingExpenseAction = ''.obs;

  // Supporting documents per leave id, for both Time Off sub-tabs.
  final leaveAttachments = <int, List<LeaveAttachment>>{}.obs;
  final downloadingAttachmentId = 0.obs;

  // ---- Allocations search / filters / group by (mirrors Odoo web) ----
  final allocationSearchQuery = ''.obs;
  final allocationStatusFilters = <AllocationStatusFilter>{}.obs;
  final allocationCurrentlyValid = false.obs;
  final allocationMyTeam = false.obs;
  final allocationMyDepartment = false.obs;
  final allocationValidityKeys = <String>{}.obs;
  final allocationGroupBys = <AllocationGroupBy>[].obs;

  // Employee-id scopes for My Team / My Department, loaded on first use.
  final _teamEmployeeIds = Rxn<Set<int>>();
  final _departmentEmployeeIds = Rxn<Set<int>>();

  late final List<ValidityStartOption> validityStartOptions =
      ValidityStartOption.buildOptions(DateTime.now());

  int get activeAllocationFilterCount =>
      allocationStatusFilters.length +
      (allocationCurrentlyValid.value ? 1 : 0) +
      (allocationMyTeam.value ? 1 : 0) +
      (allocationMyDepartment.value ? 1 : 0) +
      allocationValidityKeys.length +
      allocationGroupBys.length;

  void clearAllocationFilters() {
    allocationSearchQuery.value = '';
    allocationStatusFilters.clear();
    allocationCurrentlyValid.value = false;
    allocationMyTeam.value = false;
    allocationMyDepartment.value = false;
    allocationValidityKeys.clear();
    allocationGroupBys.clear();
  }

  void toggleAllocationStatusFilter(AllocationStatusFilter filter) {
    if (!allocationStatusFilters.remove(filter)) {
      allocationStatusFilters.add(filter);
    }
  }

  void toggleAllocationValidityKey(String key) {
    if (!allocationValidityKeys.remove(key)) {
      allocationValidityKeys.add(key);
    }
  }

  void toggleAllocationGroupBy(AllocationGroupBy groupBy) {
    if (!allocationGroupBys.remove(groupBy)) {
      allocationGroupBys.add(groupBy);
    }
  }

  void toggleAllocationMyTeam() {
    allocationMyTeam.value = !allocationMyTeam.value;
    if (allocationMyTeam.value) _ensureTeamIdsLoaded();
  }

  void toggleAllocationMyDepartment() {
    allocationMyDepartment.value = !allocationMyDepartment.value;
    if (allocationMyDepartment.value) _ensureDepartmentIdsLoaded();
  }

  Future<void> _ensureTeamIdsLoaded() async {
    if (_teamEmployeeIds.value != null) return;
    final repo = _repo;
    final userId = _auth.activeAccount.value?.userId;
    if (repo == null || userId == null) {
      _teamEmployeeIds.value = {};
      return;
    }
    final ids = await repo.fetchTeamEmployeeIds(userId);
    _teamEmployeeIds.value = ids.toSet();
  }

  Future<void> _ensureDepartmentIdsLoaded() async {
    if (_departmentEmployeeIds.value != null) return;
    final repo = _repo;
    if (repo == null) {
      _departmentEmployeeIds.value = {};
      return;
    }
    final ids = await repo.fetchDepartmentEmployeeIds(
      userId: _auth.activeAccount.value?.userId,
      employeeId: _auth.scopedEmployeeId,
    );
    _departmentEmployeeIds.value = ids.toSet();
  }

  bool _matchesAllocationFilters(LeaveAllocationRecord r) {
    final query = allocationSearchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty &&
        !r.employeeName.toLowerCase().contains(query) &&
        !r.leaveTypeName.toLowerCase().contains(query)) {
      return false;
    }

    // Status section: OR within, like Odoo.
    if (allocationStatusFilters.isNotEmpty &&
        !allocationStatusFilters.any((f) => f.matches(r))) {
      return false;
    }

    if (allocationCurrentlyValid.value) {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final from = r.dateFrom;
      final to = r.dateTo;
      if (from != null && day.isBefore(DateTime(from.year, from.month, from.day))) {
        return false;
      }
      if (to != null && day.isAfter(DateTime(to.year, to.month, to.day))) {
        return false;
      }
    }

    // My Team / My Department section: OR within. While the id sets are
    // still loading (null) the criterion is skipped rather than blanking
    // the list.
    if (allocationMyTeam.value || allocationMyDepartment.value) {
      final scopes = <Set<int>>[
        if (allocationMyTeam.value && _teamEmployeeIds.value != null)
          _teamEmployeeIds.value!,
        if (allocationMyDepartment.value &&
            _departmentEmployeeIds.value != null)
          _departmentEmployeeIds.value!,
      ];
      if (scopes.isNotEmpty) {
        final empId = r.employeeId;
        if (empId == null || !scopes.any((s) => s.contains(empId))) {
          return false;
        }
      }
    }

    // Validity Start periods: OR within.
    if (allocationValidityKeys.isNotEmpty) {
      final selected = validityStartOptions
          .where((o) => allocationValidityKeys.contains(o.key));
      if (!selected.any((o) => o.contains(r.dateFrom))) return false;
    }

    return true;
  }

  List<LeaveAllocationRecord> get visibleAllocations =>
      allocations.where(_matchesAllocationFilters).toList();

  /// Filtered rows with group headers interleaved, per the selected
  /// Group By options (nested in selection order, like Odoo).
  List<AllocationListEntry> get allocationEntries {
    final rows = visibleAllocations;
    if (allocationGroupBys.isEmpty) {
      return rows.map(AllocationListEntry.row).toList();
    }
    return _groupEntries(rows, allocationGroupBys.toList(), 0);
  }

  List<AllocationListEntry> _groupEntries(
    List<LeaveAllocationRecord> rows,
    List<AllocationGroupBy> groups,
    int level,
  ) {
    if (groups.isEmpty) {
      return rows.map(AllocationListEntry.row).toList();
    }

    final groupBy = groups.first;
    final buckets = <String, List<LeaveAllocationRecord>>{};
    for (final row in rows) {
      buckets.putIfAbsent(groupBy.keyFor(row), () => []).add(row);
    }

    final entries = <AllocationListEntry>[];
    final keys = buckets.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final key in keys) {
      final bucket = buckets[key]!;
      entries.add(AllocationListEntry.header(
        level: level,
        label: key,
        count: bucket.length,
      ));
      entries.addAll(_groupEntries(bucket, groups.sublist(1), level + 1));
    }
    return entries;
  }

  LeaveRepository? get _repo {
    final client = _auth.odooClient;
    if (client == null) return null;
    return LeaveRepository(client);
  }

  ExpenseRepository? get _expenseRepo {
    final client = _auth.odooClient;
    if (client == null) return null;
    return ExpenseRepository(client);
  }

  // Employee-mode managers only see their own team (parent_id hierarchy).
  // null = no scoping (user mode); empty = employee mode with no team, so
  // every list stays empty rather than leaking other employees' requests.
  List<int>? _teamScopeIds;
  bool _teamScopeLoaded = false;

  Future<List<int>?> _approvalScope() async {
    if (!_auth.isEmployeeMode) return null;
    if (_teamScopeLoaded) return _teamScopeIds ?? const [];

    final repo = _repo;
    final empId = _auth.scopedEmployeeId;
    if (repo == null || empId == null) return const [];
    try {
      _teamScopeIds = await repo.fetchManagedEmployeeIds(empId);
      _teamScopeLoaded = true;
    } catch (e, st) {
      ApiLogger.error('_approvalScope failed emp=$empId', e, st);
      return const [];
    }
    return _teamScopeIds;
  }

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  void setInnerTab(int index) {
    innerTabIndex.value = index;
    final keys = visibleApprovalTabs;
    if (index < 0 || index >= keys.length) return;
    switch (keys[index]) {
      case 'allocations':
        if (allocations.isEmpty && !isLoadingAllocations.value) {
          loadAllocations();
        }
      case 'expenses':
        if (allExpenses.isEmpty && !isLoadingAllExpenses.value) {
          loadExpenseApprovals();
        }
    }
  }

  /// Approval areas this account may act on, in display order. Time Off and
  /// Allocations need time-off rights; Expenses needs expense rights.
  List<String> get visibleApprovalTabs {
    if (!Get.isRegistered<MainController>()) {
      return const ['timeoff', 'allocations'];
    }
    final main = Get.find<MainController>();
    final keys = <String>[
      if (main.canApproveLeaves.value) 'timeoff',
      // 'allocations' is hidden until the tab is finished — the code behind it
      // (AllocationFilterBar, AllocationsOdooList, the fetch and approve calls)
      // is left in place, so re-adding it here brings it straight back.
      // if (main.canApproveLeaves.value) 'allocations',
      if (main.canApproveExpenses.value) 'expenses',
    ];
    return keys.isEmpty ? const ['timeoff'] : keys;
  }

  void setExpenseTab(int index) {
    expenseTabIndex.value = index;
    if (index == 0 && allExpenses.isEmpty && !isLoadingAllExpenses.value) {
      loadAllExpenses();
    }
    if (index == 1 && pendingExpenses.isEmpty && !isLoadingPendingExpenses.value) {
      loadPendingExpenses();
    }
  }

  void setTimeOffTab(int index) {
    timeOffTabIndex.value = index;
    if (index == 0 && allLeaves.isEmpty && !isLoadingAllLeaves.value) {
      loadAllTimeOff();
    }
  }

  Future<void> loadAll() async {
    await Future.wait([
      loadPendingApprovals(),
      loadAllTimeOff(),
      loadAllocations(),
    ]);
  }

  /// Employee sign-ins run as the shared Mobile App User, so a rights gap
  /// there — not the employee's own manager status — is what blocks expenses.
  String get _expenseAccessMessage => _auth.isEmployeeMode
      ? 'The Mobile App User account cannot read expenses. Ask your admin to '
          'give it Expenses access in Odoo (Settings > Users).'
      : 'Your Odoo account is not allowed to read expenses. Ask your admin to '
          'grant you Expenses access.';

  Future<void> loadExpenseApprovals() async {
    await Future.wait([
      loadAllExpenses(),
      loadPendingExpenses(),
    ]);
  }

  Future<void> loadAllExpenses() async {
    final repo = _expenseRepo;
    if (repo == null) {
      errorMessageAllExpenses.value = 'Not connected to server';
      return;
    }

    isLoadingAllExpenses.value = true;
    errorMessageAllExpenses.value = '';
    try {
      final scope = await _approvalScope();
      final rows = (scope != null && scope.isEmpty)
          ? <ExpenseApprovalItem>[]
          : await repo.fetchAllExpenses(employeeIds: scope);
      allExpenses.assignAll(rows);
    } on ExpenseAccessDenied {
      errorMessageAllExpenses.value = _expenseAccessMessage;
      allExpenses.clear();
    } catch (e, st) {
      ApiLogger.error('loadAllExpenses failed', e, st);
      errorMessageAllExpenses.value = 'Failed to load expenses';
      allExpenses.clear();
    } finally {
      isLoadingAllExpenses.value = false;
    }
  }

  Future<void> loadPendingExpenses() async {
    final repo = _expenseRepo;
    if (repo == null) {
      errorMessagePendingExpenses.value = 'Not connected to server';
      return;
    }

    isLoadingPendingExpenses.value = true;
    errorMessagePendingExpenses.value = '';
    try {
      final scope = await _approvalScope();
      final rows = (scope != null && scope.isEmpty)
          ? <ExpenseApprovalItem>[]
          : await repo.fetchExpensesToApprove(employeeIds: scope);
      pendingExpenses.assignAll(rows);
    } on ExpenseAccessDenied {
      errorMessagePendingExpenses.value = _expenseAccessMessage;
      pendingExpenses.clear();
    } catch (e, st) {
      ApiLogger.error('loadPendingExpenses failed', e, st);
      errorMessagePendingExpenses.value = 'Failed to load expense approvals';
      pendingExpenses.clear();
    } finally {
      isLoadingPendingExpenses.value = false;
    }
  }

  Future<void> approveExpense(ExpenseApprovalItem record) async {
    await _actOnExpense(
      record: record,
      actionLabel: 'approve',
      action: (repo) => repo.approveExpense(record),
    );
  }

  Future<void> refuseExpense(ExpenseApprovalItem record, String reason) async {
    await _actOnExpense(
      record: record,
      actionLabel: 'refuse',
      action: (repo) => repo.refuseExpense(record, reason),
    );
  }

  Future<void> _actOnExpense({
    required ExpenseApprovalItem record,
    required String actionLabel,
    required Future<void> Function(ExpenseRepository repo) action,
  }) async {
    final repo = _expenseRepo;
    if (repo == null) return;
    // One action at a time, enforced here rather than by grey-ing out every
    // other card in the list.
    if (isActing.value) return;

    isActing.value = true;
    actingExpenseId.value = record.id;
    actingExpenseAction.value = actionLabel;
    try {
      await action(repo);
      // The record is updated; stop showing the button as busy before the
      // list refresh, which is much slower than the action itself.
      _clearExpenseActing();
      Get.snackbar(
        'Expenses',
        'Expense ${actionLabel}d',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
      await loadExpenseApprovals();
      return;
    } catch (e) {
      Get.snackbar(
        'Expenses',
        'Could not $actionLabel this expense',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    } finally {
      _clearExpenseActing();
    }
  }

  void _clearExpenseActing() {
    isActing.value = false;
    actingExpenseId.value = 0;
    actingExpenseAction.value = '';
  }

  Future<void> loadAllTimeOff() async {
    final repo = _repo;
    if (repo == null) {
      errorMessageAllLeaves.value = 'Not connected to server';
      return;
    }

    isLoadingAllLeaves.value = true;
    errorMessageAllLeaves.value = '';
    try {
      final scope = await _approvalScope();
      final rows = (scope != null && scope.isEmpty)
          ? <LeaveRecord>[]
          : await repo.fetchAllLeaveRequests(employeeIds: scope);
      allLeaves.assignAll(rows);
      await _refreshLeaveAttachments();
    } catch (e, st) {
      ApiLogger.error('loadAllTimeOff failed', e, st);
      errorMessageAllLeaves.value = 'Failed to load time off records';
      allLeaves.clear();
    } finally {
      isLoadingAllLeaves.value = false;
    }
  }

  Future<void> loadPendingApprovals() async {
    final repo = _repo;
    if (repo == null) {
      errorMessageLeaves.value = 'Not connected to server';
      return;
    }

    isLoadingLeaves.value = true;
    errorMessageLeaves.value = '';
    try {
      final scope = await _approvalScope();
      final rows = (scope != null && scope.isEmpty)
          ? <LeaveRecord>[]
          : await repo.fetchApprovalRequests(employeeIds: scope);
      pendingLeaves.assignAll(rows);
      _home.pendingApprovals.value = rows.length;
      await _refreshLeaveAttachments();
    } catch (e, st) {
      ApiLogger.error('loadPendingApprovals failed', e, st);
      errorMessageLeaves.value = 'Failed to load time off approvals';
      pendingLeaves.clear();
    } finally {
      isLoadingLeaves.value = false;
    }
  }

  Future<void> loadAllocations() async {
    final repo = _repo;
    if (repo == null) {
      errorMessageAllocations.value = 'Not connected to server';
      return;
    }

    isLoadingAllocations.value = true;
    errorMessageAllocations.value = '';
    try {
      final scope = await _approvalScope();
      final rows = (scope != null && scope.isEmpty)
          ? <LeaveAllocationRecord>[]
          : await repo.fetchAllocationRecords(employeeIds: scope);
      allocations.assignAll(rows);
    } catch (e, st) {
      ApiLogger.error('loadAllocations failed', e, st);
      errorMessageAllocations.value = 'Failed to load allocations';
      allocations.clear();
    } finally {
      isLoadingAllocations.value = false;
    }
  }

  /// One fetch covering both Time Off sub-tabs. A failure here only hides
  /// attachment chips — the lists themselves are unaffected.
  Future<void> _refreshLeaveAttachments() async {
    final repo = _repo;
    if (repo == null) return;

    final ids = <int>{
      ...pendingLeaves.map((l) => l.id),
      ...allLeaves.map((l) => l.id),
    }.toList();
    if (ids.isEmpty) {
      leaveAttachments.clear();
      return;
    }

    try {
      final byLeave = await repo.fetchLeaveAttachments(ids);
      leaveAttachments.assignAll(byLeave);
    } catch (e, st) {
      ApiLogger.error('_refreshLeaveAttachments failed', e, st);
    }
  }

  List<LeaveAttachment> attachmentsFor(int leaveId) =>
      leaveAttachments[leaveId] ?? const [];

  Future<void> previewAttachment(LeaveAttachment attachment) async {
    final repo = _repo;
    if (repo == null || downloadingAttachmentId.value != 0) return;

    downloadingAttachmentId.value = attachment.id;
    try {
      final bytes = await repo.downloadAttachment(attachment.id);
      if (bytes == null) {
        Get.snackbar(
          'Attachments',
          'Could not load this file',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      if (attachment.mimetype.startsWith('image/')) {
        await Get.to(() => AttachmentPreviewView(
              imageBytes: bytes,
              fileName: attachment.name,
            ));
      } else if (attachment.mimetype.contains('pdf')) {
        await Get.to(() => PdfPreviewView(
              pdfBytes: bytes,
              fileName: attachment.name,
            ));
      } else {
        // No inline viewer for this type — hand off to an external app.
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${attachment.name}');
        await file.writeAsBytes(bytes);
        await OpenFilex.open(file.path);
      }
    } catch (e, st) {
      ApiLogger.error('previewAttachment id=${attachment.id}', e, st);
      Get.snackbar(
        'Attachments',
        'Could not open this file',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      downloadingAttachmentId.value = 0;
    }
  }

  Future<void> approve(LeaveRecord leave) async {
    await _actOnLeave(
      leave: leave,
      actionLabel: 'approve',
      action: (repo) => repo.approveLeave(leave.id),
    );
  }

  Future<void> refuse(LeaveRecord leave) async {
    await _actOnLeave(
      leave: leave,
      actionLabel: 'refuse',
      action: (repo) => repo.refuseLeave(leave.id),
    );
  }

  Future<void> approveAllocation(LeaveAllocationRecord row) async {
    await _actOnAllocation(
      row: row,
      actionLabel: 'approve',
      action: (repo) => repo.approveAllocation(row.id),
    );
  }

  Future<void> refuseAllocation(LeaveAllocationRecord row) async {
    await _actOnAllocation(
      row: row,
      actionLabel: 'refuse',
      action: (repo) => repo.refuseAllocation(row.id),
    );
  }

  Future<void> _actOnLeave({
    required LeaveRecord leave,
    required String actionLabel,
    required Future<void> Function(LeaveRepository repo) action,
  }) async {
    final repo = _repo;
    if (repo == null) return;

    if (isActing.value) return;

    isActing.value = true;
    actingLeaveId.value = leave.id;
    actingLeaveAction.value = actionLabel;
    try {
      await action(repo);
      _clearLeaveActing();
      Get.snackbar(
        'Approvals',
        'Leave ${leave.id} ${actionLabel}d',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
      await Future.wait([
        loadPendingApprovals(),
        loadAllTimeOff(),
      ]);
    } catch (e) {
      Get.snackbar(
        'Approvals',
        'Could not $actionLabel leave request',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    } finally {
      _clearLeaveActing();
    }
  }

  void _clearLeaveActing() {
    isActing.value = false;
    actingLeaveId.value = 0;
    actingLeaveAction.value = '';
  }

  Future<void> _actOnAllocation({
    required LeaveAllocationRecord row,
    required String actionLabel,
    required Future<void> Function(LeaveRepository repo) action,
  }) async {
    final repo = _repo;
    if (repo == null) return;

    isActing.value = true;
    actingAllocationId.value = row.id;
    try {
      await action(repo);
      Get.snackbar(
        'Allocations',
        'Allocation ${row.id} ${actionLabel}d',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
      await loadAllocations();
      await loadPendingApprovals();
      await loadAllTimeOff();
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
      actingAllocationId.value = 0;
    }
  }
}
