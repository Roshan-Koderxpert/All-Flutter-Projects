import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_logger.dart';
import '../../../core/utils/odoo_datetime.dart';
import '../../../data/models/attendance_record.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/utils/attendance_grouper.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../models/attendance_search_models.dart';

class AttendanceController extends GetxController {
  AttendanceController();

  final AuthController _auth = Get.find<AuthController>();
  final HomeController _home = Get.find<HomeController>();

  /// Upper bound on how many attendance records the history loads at once.
  /// High enough for years of data, low enough not to stall a phone.
  static const _historyLimit = 2000;

  /// True when the server had more records than [_historyLimit], so the
  /// screen can say the oldest ones are missing instead of just ending.
  final isHistoryTruncated = false.obs;

  final isLoading = false.obs;
  final panelOpen = false.obs;
  final allRecords = <AttendanceRecord>[].obs;
  final records = <AttendanceRecord>[].obs;
  final monthGroups = <AttendanceMonthGroup>[].obs;
  final errorMessage = ''.obs;

  /// No pre-selected filters — chips appear only when user picks options.
  final activeFilters = <AttendancePresetFilter>[].obs;
  final activeDateFilter = Rxn<AttendanceDateFilterSelection>();
  final selectedGroupByField = Rxn<AttendanceGroupByField>();
  final selectedDateGranularity = Rxn<AttendanceDateGroupGranularity>();

  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final filteredRecordCount = 0.obs;
  final dateFilterMenuExpanded = false.obs;
  final dateGroupByMenuExpanded = false.obs;

  final expandedMonths = <String, bool>{}.obs;
  final expandedEmployees = <String, bool>{}.obs;
  bool _didInitialExpand = false;

  AttendanceRepository? get _repo {
    final client = _auth.odooClient;
    if (client == null) return null;
    return AttendanceRepository(client);
  }

  AttendanceDateGroupGranularity get _effectiveDateGranularity =>
      selectedDateGranularity.value ?? AttendanceDateGroupGranularity.month;

  String get groupByPathLabel => AttendanceGrouper.groupByPathLabel(
        groupByField: selectedGroupByField.value,
        dateGranularity: _effectiveDateGranularity,
      );

  List<AttendanceSearchChip> get searchChips {
    final chips = <AttendanceSearchChip>[];

    for (final f in activeFilters) {
      chips.add(
        AttendanceSearchChip(
          label: f.label,
          kind: 'filter',
          filter: f,
        ),
      );
    }

    final dateF = activeDateFilter.value;
    if (dateF != null) {
      chips.add(
        AttendanceSearchChip(
          label: dateF.label,
          kind: 'dateFilter',
          dateFilter: dateF,
        ),
      );
    }

    final field = selectedGroupByField.value;
    if (field != null) {
      chips.add(
        AttendanceSearchChip(
          label: field.label,
          kind: 'groupBy',
          groupByField: field,
        ),
      );
    }

    final gran = selectedDateGranularity.value;
    if (gran != null && field == null) {
      chips.add(
        AttendanceSearchChip(
          label: gran.label,
          kind: 'groupBy',
          dateGranularity: gran,
        ),
      );
    }

    return chips;
  }

  @override
  void onInit() {
    super.onInit();
    loadHistory();
    // Reload on check-in/check-out only. Watching the hours as well would now
    // refetch the whole history on every tick of the running total.
    ever(_home.attendanceStatus, (_) => loadHistory());
    searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    searchQuery.value = searchController.text;
    _applyLocalFilters();
  }

  void clearSearch() {
    if (searchController.text.isEmpty) return;
    searchController.clear();
    searchQuery.value = '';
    _applyLocalFilters();
  }

  @override
  void onClose() {
    // Avoid disposing during account-switch route replacement frames where
    // TextField can still momentarily reference the old controller.
    super.onClose();
  }

  Future<int?> _ensureEmployeeId() async {
    if (_home.employeeId.value != null) return _home.employeeId.value;
    await _home.loadDashboard();
    return _home.employeeId.value;
  }

  Future<List<List<dynamic>>> _buildServerDomain(int? empId) async {
    final domain = <List<dynamic>>[];

    final my = activeFilters.contains(AttendancePresetFilter.myAttendances);
    final team = activeFilters.contains(AttendancePresetFilter.myTeam);

    if (team && empId != null) {
      final teamIds = await _repo!.fetchTeamEmployeeIds(empId);
      final ids = <int>{empId, ...teamIds}.toList();
      if (ids.isNotEmpty) {
        domain.add(['employee_id', 'in', ids]);
      }
    } else if (my && empId != null) {
      domain.add(['employee_id', '=', empId]);
    } else if (empId != null) {
      domain.add(['employee_id', '=', empId]);
    }

    if (activeFilters.contains(AttendancePresetFilter.atWork)) {
      domain.add(['check_out', '=', false]);
    }

    final active = activeFilters.contains(AttendancePresetFilter.activeEmployees);
    final archived =
        activeFilters.contains(AttendancePresetFilter.archivedEmployees);
    if (active && !archived) {
      domain.add(['employee_id.active', '=', true]);
    } else if (archived && !active) {
      domain.add(['employee_id.active', '=', false]);
    }

    final dateF = activeDateFilter.value;
    if (dateF != null) {
      domain.add(['check_in', '>=', OdooDateTime.toOdooUtc(dateF.from)]);
      domain.add([
        'check_in',
        '<',
        OdooDateTime.toOdooUtc(
          dateF.to.add(const Duration(days: 1)),
        ),
      ]);
    }
    // No default date restriction: Odoo's Attendances list has none, so adding
    // one here made the app's history end months earlier than the web's.

    return domain;
  }

  Future<void> loadHistory() async {
    ApiLogger.info('--- AttendanceController.loadHistory ---');
    final repo = _repo;
    if (repo == null) {
      errorMessage.value = 'Not connected to server';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final empId = await _ensureEmployeeId();
      if (empId == null) {
        errorMessage.value = 'Employee record not found';
        allRecords.clear();
        records.clear();
        monthGroups.clear();
        filteredRecordCount.value = 0;
        return;
      }

      final domain = await _buildServerDomain(empId);
      ApiLogger.json('domain', domain);

      final list =
          await repo.fetchAttendance(domain: domain, limit: _historyLimit);
      // 250 silently cut the history off mid-May; a cap is still sensible on
      // mobile, but the user has to be told when it applies.
      isHistoryTruncated.value = list.length >= _historyLimit;
      if (isHistoryTruncated.value) {
        ApiLogger.info(
          'loadHistory hit the $_historyLimit record cap — older attendance '
          'is not shown',
        );
      }
      allRecords.assignAll(list);
      _applyLocalFilters();
    } catch (e, st) {
      ApiLogger.error('loadHistory failed', e, st);
      errorMessage.value = 'Failed to load attendance history';
      allRecords.clear();
      records.clear();
      monthGroups.clear();
      filteredRecordCount.value = 0;
    } finally {
      isLoading.value = false;
    }
  }

  void _applyLocalFilters() {
    var list = allRecords.toList();

    if (activeFilters.contains(AttendancePresetFilter.errors)) {
      list = list.where(_isErrorRecord).toList();
    }

    if (activeFilters.contains(AttendancePresetFilter.autoCheckedOut)) {
      list = list.where(_isAutoCheckedOut).toList();
    }

    final q = searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) => _matchesSearch(r, q)).toList();
    }

    records.assignAll(list);
    filteredRecordCount.value = list.length;
    _rebuildGroups();
  }

  bool get hasActiveSearch => searchQuery.value.trim().isNotEmpty;

  bool _matchesSearch(AttendanceRecord r, String q) {
    final employeeName = r.employeeName.isNotEmpty
        ? r.employeeName
        : _home.employeeName.value;
    final checkInText = r.checkInLabel.toLowerCase();
    final checkOutText = r.checkOutLabel.toLowerCase();

    return employeeName.toLowerCase().contains(q) ||
        r.departmentName.toLowerCase().contains(q) ||
        r.managerName.toLowerCase().contains(q) ||
        r.methodLabel.toLowerCase().contains(q) ||
        checkInText.contains(q) ||
        checkOutText.contains(q) ||
        r.workedHoursLabel.toLowerCase().contains(q) ||
        r.id.toString().contains(q);
  }

  bool _isErrorRecord(AttendanceRecord r) {
    if (r.isOpen) {
      final hoursOpen = DateTime.now().difference(r.checkIn).inHours;
      return hoursOpen > 16;
    }
    return r.workedHours <= 0.01;
  }

  bool _isAutoCheckedOut(AttendanceRecord r) {
    if (r.outMode.toLowerCase().contains('auto')) return true;
    if (r.checkOut == null) return false;
    final duration = r.checkOut!.difference(r.checkIn);
    return duration.inMinutes <= 1 && r.workedHours <= 0.05;
  }

  void _rebuildGroups() {
    monthGroups.assignAll(
      AttendanceGrouper.build(
        records.toList(),
        groupByField: selectedGroupByField.value,
        dateGranularity: _effectiveDateGranularity,
        fallbackEmployeeName: _home.employeeName.value.isNotEmpty
            ? _home.employeeName.value
            : 'Employee',
      ),
    );
    if (!_didInitialExpand && monthGroups.isNotEmpty) {
      expandedMonths[monthGroups.first.monthKey] = true;
      final firstEmp = monthGroups.first.employees;
      if (firstEmp.isNotEmpty) {
        expandedEmployees[employeeGroupKey(
          monthGroups.first.monthKey,
          firstEmp.first.employeeId,
        )] = true;
      }
      _didInitialExpand = true;
    }
  }

  void toggleDateFilterMenu() =>
      dateFilterMenuExpanded.value = !dateFilterMenuExpanded.value;

  void toggleDateGroupByMenu() =>
      dateGroupByMenuExpanded.value = !dateGroupByMenuExpanded.value;

  bool _isLocalOnlyFilter(AttendancePresetFilter f) =>
      f == AttendancePresetFilter.errors ||
      f == AttendancePresetFilter.autoCheckedOut;

  void toggleFilter(AttendancePresetFilter filter) {
    if (activeFilters.contains(filter)) {
      activeFilters.remove(filter);
    } else {
      if (filter == AttendancePresetFilter.activeEmployees) {
        activeFilters.remove(AttendancePresetFilter.archivedEmployees);
      }
      if (filter == AttendancePresetFilter.archivedEmployees) {
        activeFilters.remove(AttendancePresetFilter.activeEmployees);
      }
      if (filter == AttendancePresetFilter.myAttendances) {
        activeFilters.remove(AttendancePresetFilter.myTeam);
      }
      if (filter == AttendancePresetFilter.myTeam) {
        activeFilters.remove(AttendancePresetFilter.myAttendances);
      }
      activeFilters.add(filter);
    }
    activeFilters.refresh();

    if (_isLocalOnlyFilter(filter)) {
      _applyLocalFilters();
    } else {
      loadHistory();
    }
  }

  void removeChip(AttendanceSearchChip chip) {
    if (chip.kind == 'dateFilter' && chip.dateFilter != null) {
      activeDateFilter.value = null;
      loadHistory();
      return;
    }
    if (chip.kind == 'groupBy') {
      if (chip.groupByField != null) {
        selectedGroupByField.value = null;
      }
      if (chip.dateGranularity != null) {
        selectedDateGranularity.value = null;
      }
      _rebuildGroups();
      return;
    }
    if (chip.filter != null) {
      toggleFilter(chip.filter!);
    }
  }

  void setGroupByField(AttendanceGroupByField field) {
    selectedGroupByField.value = field;
    selectedDateGranularity.value = null;
    _rebuildGroups();
  }

  void setDateGroupGranularity(AttendanceDateGroupGranularity granularity) {
    selectedDateGranularity.value = granularity;
    selectedGroupByField.value = null;
    _rebuildGroups();
  }

  void applyMonthDateFilter(int year, int month, String monthName) {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0);
    activeDateFilter.value = AttendanceDateFilterSelection(
      label: monthName,
      from: from,
      to: to,
    );
    loadHistory();
  }

  void applyQuarterDateFilter(int year, int quarter) {
    final startMonth = (quarter - 1) * 3 + 1;
    final from = DateTime(year, startMonth, 1);
    final endMonth = startMonth + 2;
    final to = DateTime(year, endMonth + 1, 0);
    activeDateFilter.value = AttendanceDateFilterSelection(
      label: 'Q$quarter',
      from: from,
      to: to,
    );
    loadHistory();
  }

  void applyYearDateFilter(int year) {
    activeDateFilter.value = AttendanceDateFilterSelection(
      label: year.toString(),
      from: DateTime(year, 1, 1),
      to: DateTime(year, 12, 31),
    );
    loadHistory();
  }

  void clearAllFilters() {
    activeFilters.clear();
    activeDateFilter.value = null;
    selectedGroupByField.value = null;
    selectedDateGranularity.value = null;
    dateFilterMenuExpanded.value = false;
    dateGroupByMenuExpanded.value = false;
    activeFilters.refresh();
    loadHistory();
  }

  List<({int year, int month, String name})> get recentMonths {
    final now = DateTime.now();
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return List.generate(3, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return (year: d.year, month: d.month, name: names[d.month - 1]);
    });
  }

  List<int> get recentYears {
    final y = DateTime.now().year;
    return [y, y - 1, y - 2];
  }

  String employeeGroupKey(String monthKey, int employeeId) =>
      '${monthKey}_$employeeId';

  void toggleMonth(String monthKey) {
    expandedMonths[monthKey] = !(expandedMonths[monthKey] ?? false);
  }

  void toggleEmployee(String key) {
    expandedEmployees[key] = !(expandedEmployees[key] ?? false);
  }

  bool isMonthExpanded(String monthKey) => expandedMonths[monthKey] ?? false;

  bool isEmployeeExpanded(String key) => expandedEmployees[key] ?? false;
}
