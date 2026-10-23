import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_logger.dart';
import '../../approvals/controllers/approvals_controller.dart';
import '../../attendance/controllers/attendance_controller.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../leave/controllers/leave_controller.dart';
import '../../timesheet/controllers/timesheet_controller.dart';
import '../controllers/home_controller.dart';

class MainController extends GetxController {
  final currentIndex = 0.obs;
  final canAccessApprovals = false.obs;
  final notchBarController = NotchBottomBarController(index: 0);
  final AuthController _auth = Get.find<AuthController>();
  /// The tabs currently shown, in order, as stable keys. User mode always has
  /// the full set; employee mode drops Approvals and any feature the admin
  /// turned off for that employee. Kept to >= 2 so the notch bar stays valid.
  List<String> get visibleTabKeys {
    final keys = <String>['home'];
    if (canUse('attendance')) keys.add('attendance');
    if (canUse('leave')) keys.add('leave');
    if (canUse('timesheet')) keys.add('timesheet');
    if (canAccessApprovals.value) keys.add('approvals');
    // The notch bar needs at least two items; if an employee somehow has every
    // feature off, fall back to the core tabs so the bar stays valid.
    if (keys.length < 2) {
      return const ['home', 'attendance', 'leave', 'timesheet'];
    }
    return keys;
  }

  static String titleForTabKey(String key) {
    switch (key) {
      case 'home':
        return 'Home';
      case 'attendance':
        return 'Attendance';
      case 'leave':
        return 'Leaves';
      case 'timesheet':
        return 'Timesheets';
      case 'approvals':
        return 'Approvals';
      default:
        return '';
    }
  }

  List<String> get screenTitles => visibleTabKeys.map(titleForTabKey).toList();

  String get currentTitle {
    final titles = screenTitles;
    final idx = currentIndex.value.clamp(0, titles.length - 1);
    return titles[idx];
  }

  int get timesheetTabIndex => visibleTabKeys.indexOf('timesheet');
  int get approvalsTabIndex => visibleTabKeys.indexOf('approvals');

  @override
  void onInit() {
    super.onInit();
    refreshApprovalsAccess();
  }

  /// Whether the current session may use [feature] (user mode: always;
  /// employee mode: only where the admin enabled that employee's toggle).
  bool canUse(String feature) => _auth.employeeCanUse(feature);

  bool get isEmployeeMode => _auth.isEmployeeMode;

  /// Which approval areas this account may use. The Approvals screen opens if
  /// either is true, and each tab inside it is shown per its own right — so an
  /// expenses-only approver sees the screen with just the Expenses tab.
  final canApproveLeaves = false.obs;
  final canApproveExpenses = false.obs;

  Future<void> refreshApprovalsAccess() async {
    final client = _auth.odooClient;
    if (client == null) {
      ApiLogger.info('refreshApprovalsAccess: odooClient is null');
      canAccessApprovals.value = false;
      return;
    }

    // Employee mode has no personal res.users account, so group checks can't
    // apply. Instead: the tab shows only when someone reports to this
    // employee (hr.employee.parent_id hierarchy), and the Approvals screen
    // scopes itself to that team.
    if (_auth.isEmployeeMode) {
      final empId = _auth.scopedEmployeeId;
      if (empId == null) {
        canAccessApprovals.value = false;
        return;
      }
      try {
        final teamIds =
            await LeaveRepository(client).fetchManagedEmployeeIds(empId);
        final isManager = teamIds.isNotEmpty;
        canApproveLeaves.value = isManager;
        canApproveExpenses.value = isManager;
        canAccessApprovals.value = isManager;
        ApiLogger.info(
          'refreshApprovalsAccess employee-mode manager check emp=$empId '
          'team=${teamIds.length} => ${canAccessApprovals.value}',
        );
      } catch (_) {
        ApiLogger.error('refreshApprovalsAccess employee-mode check failed');
        canApproveLeaves.value = false;
        canApproveExpenses.value = false;
        canAccessApprovals.value = false;
      }
      if (currentIndex.value >= visibleTabKeys.length) {
        currentIndex.value = 0;
        notchBarController.jumpTo(0);
      }
      return;
    }

    try {
      ApiLogger.info(
        'refreshApprovalsAccess: user=${_auth.activeAccount.value?.username} db=${_auth.activeAccount.value?.database}',
      );
      final results = await Future.wait([
        LeaveRepository(client).hasApprovalAccess(),
        ExpenseRepository(client).hasExpenseApprovalAccess(),
      ]);
      canApproveLeaves.value = results[0];
      canApproveExpenses.value = results[1];
      canAccessApprovals.value = results[0] || results[1];
      ApiLogger.info(
        'refreshApprovalsAccess result => leaves=${results[0]} '
        'expenses=${results[1]} screen=${canAccessApprovals.value}',
      );
    } catch (_) {
      ApiLogger.error('refreshApprovalsAccess failed');
      canApproveLeaves.value = false;
      canApproveExpenses.value = false;
      canAccessApprovals.value = false;
    }

    if (currentIndex.value >= visibleTabKeys.length) {
      currentIndex.value = 0;
      notchBarController.jumpTo(0);
    }
  }

  void changeTab(int index) {
    final maxIndex = screenTitles.length - 1;
    final safeIndex = index.clamp(0, maxIndex);
    if (safeIndex == currentIndex.value) return;
    currentIndex.value = safeIndex;
    if (notchBarController.index != safeIndex) {
      notchBarController.jumpTo(safeIndex);
    }
    _onTabChanged(safeIndex);
  }

  void _onTabChanged(int index) {
    final keys = visibleTabKeys;
    if (index < 0 || index >= keys.length) return;
    switch (keys[index]) {
      case 'home':
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().refreshTodayAttendance();
        }
        break;
      case 'attendance':
        if (Get.isRegistered<AttendanceController>()) {
          Get.find<AttendanceController>().loadHistory();
        }
        break;
      case 'leave':
        if (Get.isRegistered<LeaveController>()) {
          Get.find<LeaveController>().loadLeaves();
        }
        break;
      case 'timesheet':
        if (Get.isRegistered<TimesheetController>()) {
          Get.find<TimesheetController>().loadAll();
        }
        break;
      case 'approvals':
        if (Get.isRegistered<ApprovalsController>()) {
          Get.find<ApprovalsController>().loadAll();
        }
        break;
    }
  }
}
