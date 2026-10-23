import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_logger.dart';
import '../../../data/models/leave_balance_item.dart';
import '../../../data/models/leave_calendar_info_item.dart';
import '../../../data/models/leave_record.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_controller.dart';

enum LeaveListFilter { all, pending, approved, refused }
enum LeaveScreenMode { calendar, list }

extension LeaveListFilterX on LeaveListFilter {
  String get label => switch (this) {
        LeaveListFilter.all => 'All',
        LeaveListFilter.pending => 'Pending',
        LeaveListFilter.approved => 'Approved',
        LeaveListFilter.refused => 'Refused',
      };
}

class LeaveController extends GetxController {
  final AuthController _auth = Get.find<AuthController>();
  final HomeController _home = Get.find<HomeController>();

  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  final balances = <LeaveBalanceItem>[].obs;
  final allRequests = <LeaveRecord>[].obs;
  final filteredRequests = <LeaveRecord>[].obs;
  final leaveTypes = <LeaveTypeOption>[].obs;
  final mandatoryDays = <LeaveCalendarInfoItem>[].obs;
  final publicHolidays = <LeaveCalendarInfoItem>[].obs;
  final unusualDays = <String>{}.obs;

  final selectedFilter = LeaveListFilter.all.obs;
  final screenMode = LeaveScreenMode.calendar.obs;
  final cancellingLeaveId = RxnInt();
  final savingLeaveId = RxnInt();
  final activeEmployeeId = RxnInt();

  bool get isInitialLoad =>
      isLoading.value && balances.isEmpty && allRequests.isEmpty;

  LeaveRepository? get _repo {
    final client = _auth.odooClient;
    if (client == null) return null;
    return LeaveRepository(client);
  }

  Future<int?> _resolveEmployeeId() async {
    // Employee mode: scope to the employee from login, never the shared user
    // (which would overwrite the header with the shared account's employee).
    final scoped = _auth.scopedEmployeeId;
    if (scoped != null) {
      _home.employeeId.value = scoped;
      return scoped;
    }

    final userId = _auth.activeAccount.value?.userId;
    final client = _auth.odooClient;
    if (userId == null || client == null) return null;

    try {
      final resolved = await EmployeeRepository(client).resolveForUser(userId);
      if (resolved == null) {
        ApiLogger.error('Leave: no employee linked to userId=$userId');
        return null;
      }

      _home.employeeId.value = resolved.id;
      if (resolved.name.isNotEmpty) {
        _home.employeeName.value = resolved.name;
      }
      if (resolved.jobTitle.isNotEmpty) {
        _home.jobTitle.value = resolved.jobTitle;
      }
      if (resolved.departmentName.isNotEmpty) {
        _home.departmentName.value = resolved.departmentName;
      }

      ApiLogger.info(
        'Leave: employee=${resolved.id} (${resolved.name}) for userId=$userId',
      );
      return resolved.id;
    } catch (e, st) {
      ApiLogger.error('_resolveEmployeeId failed userId=$userId', e, st);
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever(selectedFilter, (_) => _applyFilter());
  }

  Future<void> loadLeaves() async {
    final repo = _repo;
    if (repo == null) {
      errorMessage.value = 'Not connected to server';
      return;
    }

    var empId = await _resolveEmployeeId();
    if (empId == null) {
      errorMessage.value = 'Employee record not found';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      activeEmployeeId.value = empId;
      final balanceList = await repo.fetchBalances(empId);
      final results = await Future.wait([
        Future<List<LeaveBalanceItem>>.value(balanceList),
        repo.fetchLeaveRequests(employeeId: empId),
        repo.fetchRequestableTypes(empId, balances: balanceList),
        repo.fetchMandatoryDays(employeeId: empId),
        repo.fetchPublicHolidays(employeeId: empId),
      ]);

      balances.assignAll(results[0] as List<LeaveBalanceItem>);
      allRequests.assignAll(_scopedRequests(results[1] as List<LeaveRecord>));
      leaveTypes.assignAll(results[2] as List<LeaveTypeOption>);
      mandatoryDays.assignAll(results[3] as List<LeaveCalendarInfoItem>);
      publicHolidays.assignAll(results[4] as List<LeaveCalendarInfoItem>);

      _home.leaveBalances.assignAll(balances);
      _applyFilter();
      await refreshUnusualDaysForRange(
        DateTime.now().subtract(const Duration(days: 370)),
        DateTime.now().add(const Duration(days: 370)),
      );

      ApiLogger.info(
        'loadLeaves ok balances=${balances.length} requests=${allRequests.length}',
      );
    } catch (e, st) {
      ApiLogger.error('loadLeaves failed', e, st);
      errorMessage.value = 'Failed to load leave data';
    } finally {
      isLoading.value = false;
    }
  }

  void setFilter(LeaveListFilter filter) {
    selectedFilter.value = filter;
  }

  void setScreenMode(LeaveScreenMode mode) {
    screenMode.value = mode;
  }

  List<LeaveRecord> _scopedRequests(List<LeaveRecord> records) {
    final empId = activeEmployeeId.value;
    if (empId == null) return records;
    return records
        .where((r) => r.employeeId == null || r.employeeId == empId)
        .toList();
  }

  void _applyFilter() {
    final filter = selectedFilter.value;
    filteredRequests.assignAll(
      allRequests.where((r) {
        return switch (filter) {
          LeaveListFilter.all => true,
          LeaveListFilter.pending => r.state.isPending,
          LeaveListFilter.approved => r.state == LeaveState.approved,
          LeaveListFilter.refused =>
            r.state == LeaveState.refused || r.state == LeaveState.cancelled,
        };
      }),
    );
  }

  Future<bool> submitLeaveRequest({
    required LeaveTypeOption type,
    required DateTime dateFrom,
    required DateTime dateTo,
    required String description,
    bool showSuccessSnackbar = true,
    bool halfDay = false,
    HalfDayPeriod halfDayPeriod = HalfDayPeriod.morning,
    bool customHours = false,
    double? hourFrom,
    double? hourTo,
    List<LeaveAttachmentUpload> attachments = const [],
  }) async {
    final repo = _repo;
    final empId = await _resolveEmployeeId();

    if (repo == null || empId == null) {
      Get.snackbar(
        'Leave',
        'Employee record not found',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return false;
    }

    // Half-day / custom-hours requests always cover a single date.
    if (halfDay || customHours) {
      dateTo = dateFrom;
    }

    if (customHours) {
      if (hourFrom == null || hourTo == null || hourTo <= hourFrom) {
        Get.snackbar(
          'Leave',
          'End time must be after start time',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    }

    if (dateTo.isBefore(dateFrom)) {
      Get.snackbar(
        'Leave',
        'End date must be on or after start date',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (isPastCalendarDay(dateFrom)) {
      Get.snackbar(
        'Leave',
        'You cannot request time off for past dates.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return false;
    }

    if (rangeContainsMandatoryDay(dateFrom, dateTo)) {
      Get.snackbar(
        'Leave',
        'You are not allowed to request time off on a mandatory day.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return false;
    }

    final overlap = _findOverlappingRequest(dateFrom, dateTo);
    if (overlap != null) {
      Get.snackbar(
        'Leave',
        'You already have ${overlap.state.label.toLowerCase()} leave for ${overlap.dateRangeLabel}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return false;
    }

    // For half-day/hours the exact duration is known locally (server still
    // recomputes with the working calendar as the source of truth).
    final requestedDays = halfDay
        ? 0.5
        : customHours
            ? ((hourTo! - hourFrom!) / 8).clamp(0.05, 1.0).toDouble()
            : await repo.computeRequestedLeaveDays(
                employeeId: empId,
                leaveTypeId: type.id,
                dateFrom: dateFrom,
                dateTo: dateTo,
                publicHolidays: publicHolidays,
                mandatoryDays: mandatoryDays,
              );

    if (requestedDays <= 0) {
      Get.snackbar(
        'Leave',
        'No working days in the selected date range.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (type.requiresAllocation && type.remainingDays != null) {
      if (requestedDays > type.remainingDays!) {
        Get.snackbar(
          'Leave',
          'You only have ${type.remainingDays!.toStringAsFixed(1)} days left for ${type.name}, but this request needs ${requestedDays.toStringAsFixed(1)} days.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
        );
        return false;
      }
    }

    isSubmitting.value = true;
    try {
      final createdId = await repo.createLeaveRequest(
        employeeId: empId,
        leaveTypeId: type.id,
        dateFrom: dateFrom,
        dateTo: dateTo,
        description: description,
        halfDay: halfDay,
        halfDayPeriod: halfDayPeriod,
        customHours: customHours,
        hourFrom: hourFrom,
        hourTo: hourTo,
      );
      if (createdId == null) {
        throw Exception('Leave request was not created');
      }

      if (attachments.isNotEmpty) {
        final uploaded =
            await repo.uploadLeaveAttachments(createdId, attachments);
        if (uploaded < attachments.length) {
          Get.snackbar(
            'Leave',
            'Request submitted, but some documents could not be uploaded.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.shade100,
            colorText: Colors.orange.shade900,
          );
        }
      }

      await loadLeaves();
      if (showSuccessSnackbar) {
        Get.snackbar(
          'Success',
          'Leave request submitted',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900,
        );
      }
      return true;
    } catch (e) {
      final message = _friendlyErrorMessage(e);
      Get.snackbar(
        'Leave',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> cancelLeaveRequest(
    LeaveRecord leave, {
    String successMessage = 'Leave request cancelled',
  }) async {
    final repo = _repo;
    if (repo == null) return false;
    if (!canCancel(leave)) {
      Get.snackbar(
        'Leave',
        leave.isStartTodayOrFuture
            ? 'This leave request cannot be cancelled.'
            : 'Past time off requests cannot be cancelled.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    cancellingLeaveId.value = leave.id;
    try {
      await repo.cancelLeaveRequest(leave.id, state: leave.state);
      await loadLeaves();
      Get.snackbar(
        'Leave',
        successMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
      return true;
    } catch (e) {
      Get.snackbar(
        'Leave',
        _friendlyErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return false;
    } finally {
      cancellingLeaveId.value = null;
    }
  }

  Future<bool> updateLeaveRequest({
    required LeaveRecord original,
    required LeaveTypeOption type,
    required DateTime dateFrom,
    required DateTime dateTo,
    required String description,
  }) async
  {
    final repo = _repo;
    if (repo == null) return false;
    if (!(original.state == LeaveState.draft || original.state.isPending)) {
      Get.snackbar(
        'Leave',
        'Only draft or pending requests can be edited.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
    if (dateTo.isBefore(dateFrom)) {
      Get.snackbar(
        'Leave',
        'End date must be on or after start date',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (isPastCalendarDay(dateFrom) &&
        !normalizeCalendarDay(original.dateFrom)
            .isBefore(earliestNewRequestDate)) {
      Get.snackbar(
        'Leave',
        'You cannot request time off for past dates.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (rangeContainsMandatoryDay(dateFrom, dateTo)) {
      Get.snackbar(
        'Leave',
        'You are not allowed to request time off on a mandatory day.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return false;
    }

    final overlap = _findOverlappingRequest(
      dateFrom,
      dateTo,
      excludeLeaveId: original.id,
    );
    if (overlap != null) {
      Get.snackbar(
        'Leave',
        'This overlaps with ${overlap.dateRangeLabel}.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final empId = activeEmployeeId.value ?? await _resolveEmployeeId();
    if (empId == null) {
      Get.snackbar(
        'Leave',
        'Employee record not found',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final requestedDays = await repo.computeRequestedLeaveDays(
      employeeId: empId,
      leaveTypeId: type.id,
      dateFrom: dateFrom,
      dateTo: dateTo,
      publicHolidays: publicHolidays,
      mandatoryDays: mandatoryDays,
    );

    if (requestedDays <= 0) {
      Get.snackbar(
        'Leave',
        'No working days in the selected date range.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (type.requiresAllocation && type.remainingDays != null) {
      final sameType =
          original.leaveTypeId == null || original.leaveTypeId == type.id;
      final available = sameType
          ? type.remainingDays! + original.numberOfDays
          : type.remainingDays!;
      if (requestedDays > available) {
        Get.snackbar(
          'Leave',
          'You only have ${available.toStringAsFixed(1)} days available for ${type.name}, but this request needs ${requestedDays.toStringAsFixed(1)} days.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
        );
        return false;
      }
    }

    savingLeaveId.value = original.id;
    try {
      await repo.updateLeaveRequest(
        leaveId: original.id,
        employeeId: empId,
        leaveTypeId: type.id,
        dateFrom: dateFrom,
        dateTo: dateTo,
        description: description,
      );
      await loadLeaves();
      Get.snackbar(
        'Leave',
        'Leave request updated',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
      return true;
    } catch (e) {
      Get.snackbar(
        'Leave',
        _friendlyErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return false;
    } finally {
      savingLeaveId.value = null;
    }
  }

  bool isDateBlocked(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    for (final r in allRequests) {
      if (r.state == LeaveState.refused || r.state == LeaveState.cancelled) {
        continue;
      }
      final start = DateTime(r.dateFrom.year, r.dateFrom.month, r.dateFrom.day);
      final end = DateTime(r.dateTo.year, r.dateTo.month, r.dateTo.day);
      if (!d.isBefore(start) && !d.isAfter(end)) return true;
    }
    return false;
  }

  /// Odoo self-service: new requests start today or later (local calendar day).
  DateTime get earliestNewRequestDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Odoo does not cap far-future requests on the employee form; allow several years ahead.
  DateTime get latestNewRequestDate {
    final now = DateTime.now();
    return DateTime(now.year + 10, 12, 31);
  }

  static DateTime normalizeCalendarDay(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  String _dayKey(DateTime day) {
    final d = normalizeCalendarDay(day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  bool isPastCalendarDay(DateTime day) =>
      normalizeCalendarDay(day).isBefore(earliestNewRequestDate);

  bool isMandatoryDay(DateTime day) => _isWithinCalendarItems(day, mandatoryDays);

  bool isPublicHoliday(DateTime day) =>
      _isWithinCalendarItems(day, publicHolidays);

  bool isUnusualDay(DateTime day) => unusualDays.contains(_dayKey(day));

  bool _isWithinCalendarItems(
    DateTime day,
    List<LeaveCalendarInfoItem> items,
  ) {
    final d = normalizeCalendarDay(day);
    for (final item in items) {
      final from = item.dateFrom;
      if (from == null) continue;
      final start = normalizeCalendarDay(from);
      final end = normalizeCalendarDay(item.dateTo ?? from);
      if (!d.isBefore(start) && !d.isAfter(end)) return true;
    }
    return false;
  }

  bool rangeContainsMandatoryDay(DateTime from, DateTime to) {
    var current = normalizeCalendarDay(from);
    final end = normalizeCalendarDay(to);
    while (!current.isAfter(end)) {
      if (isMandatoryDay(current)) return true;
      current = current.add(const Duration(days: 1));
    }
    return false;
  }

  /// Calendar tap / start-date picker for a brand-new request.
  bool canApplyNewLeaveOnDay(DateTime day) {
    if (isPastCalendarDay(day)) return false;
    if (isMandatoryDay(day)) return false;
    if (isUnusualDay(day)) return false;
    if (isDateBlocked(day)) return false;
    return true;
  }

  /// End-date picker: allow ranges over weekends, still block past/mandatory/overlap.
  bool canSelectEndDateForNewRequest(DateTime day) {
    if (isPastCalendarDay(day)) return false;
    if (isMandatoryDay(day)) return false;
    if (isDateBlocked(day)) return false;
    return true;
  }

  String? blockedNewLeaveDayMessage(DateTime day) {
    if (isPastCalendarDay(day)) {
      return 'You cannot request time off for past dates.';
    }
    if (isMandatoryDay(day)) {
      return 'You are not allowed to request time off on a mandatory day.';
    }
    if (isUnusualDay(day)) {
      return 'This day is not a working day in your schedule.';
    }
    if (isDateBlocked(day)) {
      return 'You already have leave booked on this date.';
    }
    return null;
  }

  DateTime earliestEditableRequestDate(LeaveRecord original) {
    final originalStart = normalizeCalendarDay(original.dateFrom);
    if (original.state == LeaveState.draft ||
        original.state.isPending) {
      return originalStart.isBefore(earliestNewRequestDate)
          ? originalStart
          : earliestNewRequestDate;
    }
    return earliestNewRequestDate;
  }

  Future<void> refreshUnusualDaysForRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    final repo = _repo;
    final empId = activeEmployeeId.value ?? await _resolveEmployeeId();
    if (repo == null || empId == null) return;

    try {
      final days = await repo.fetchUnusualDays(
        employeeId: empId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      unusualDays.assignAll(days);
    } catch (e, st) {
      ApiLogger.error('refreshUnusualDaysForRange failed', e, st);
    }
  }

  bool canCancel(LeaveRecord leave) => leave.isCancellableByEmployee;

  List<LeaveRecord> requestsOnDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return allRequests.where((r) {
      final start = DateTime(r.dateFrom.year, r.dateFrom.month, r.dateFrom.day);
      final end = DateTime(r.dateTo.year, r.dateTo.month, r.dateTo.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  LeaveRecord? _findOverlappingRequest(
    DateTime from,
    DateTime to, {
    int? excludeLeaveId,
  }) {
    final requestedStart = DateTime(from.year, from.month, from.day);
    final requestedEnd = DateTime(to.year, to.month, to.day, 23, 59, 59);

    for (final r in allRequests) {
      if (excludeLeaveId != null && r.id == excludeLeaveId) continue;
      if (r.state == LeaveState.refused || r.state == LeaveState.cancelled) {
        continue;
      }
      final existingStart =
          DateTime(r.dateFrom.year, r.dateFrom.month, r.dateFrom.day);
      final existingEnd =
          DateTime(r.dateTo.year, r.dateTo.month, r.dateTo.day, 23, 59, 59);

      final overlaps = requestedStart.isBefore(existingEnd) &&
          requestedEnd.isAfter(existingStart);
      if (overlaps ||
          requestedStart.isAtSameMomentAs(existingStart) ||
          requestedEnd.isAtSameMomentAs(existingEnd)) {
        return r;
      }
    }
    return null;
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('overlaps with this period')) {
      return 'You already have leave in this date range. Please choose different dates.';
    }
    if (raw.contains('ValidationError')) {
      return 'Leave request rejected by server rules. Please verify dates and leave type.';
    }
    if (raw.contains('not enough') ||
        raw.contains('allocation') ||
        raw.contains('valid allocation') ||
        raw.contains('no valid allocation')) {
      return 'Insufficient leave allocation for selected leave type.';
    }
    return 'Could not submit leave request. Please try again.';
  }
}
