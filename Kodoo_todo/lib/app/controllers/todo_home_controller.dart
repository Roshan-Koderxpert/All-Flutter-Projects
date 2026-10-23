import 'package:get/get.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import 'login_controller.dart';

/// Dashboard stats from Odoo [project.task] aligned with the **To-Do** app
/// (`project_todo`): personal tasks only (`project_id` unset), top-level rows only
/// (no sub-tasks), assigned to the current user.
///
/// **Today / This week / This month** match Odoo’s Kanban columns: they use
/// [personal_stage_type_ids] (see [project.task.type] rows for the user), not
/// [date_deadline] (often empty on to-dos).
class TodoHomeController extends GetxController {
  final AuthController _auth = Get.find<AuthController>();

  final isLoading = false.obs;
  final loadError = RxnString();

  final countAll = 0.obs;
  final countPending = 0.obs;
  final countCompleted = 0.obs;

  final countDueToday = 0.obs;
  final countDueThisWeek = 0.obs;
  final countDueThisMonth = 0.obs;

  static const String _model = 'project.task';
  static const String _stageModel = 'project.task.type';

  static final List<String> _doneStates = ['1_done', 'done'];
  static final List<String> _closedStates = [
    '1_done',
    '1_canceled',
    'done',
    'cancelled',
  ];

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Prefix notation: AND of [conditions] (each item is one domain leaf).
  static List<dynamic> _andAll(List<dynamic> conditions) {
    if (conditions.isEmpty) return [];
    if (conditions.length == 1) return [conditions[0]];
    return [
      for (var i = 0; i < conditions.length - 1; i++) '&',
      ...conditions,
    ];
  }

  static List<dynamic> _assigneeLeaf(int uid, {required bool legacyUserIdField}) {
    if (legacyUserIdField) {
      return ['user_id', '=', uid];
    }
    return ['user_ids', 'in', [uid]];
  }

  static List<dynamic> _todoScopeBase(int uid, {required bool legacyUserIdField}) {
    return _andAll([
      _assigneeLeaf(uid, legacyUserIdField: legacyUserIdField),
      ['active', '=', true],
      ['project_id', '=', false],
      ['parent_id', '=', false],
    ]);
  }

  static List<dynamic> _myActiveTasksDomain(int uid, {required bool legacyUserIdField}) =>
      _todoScopeBase(uid, legacyUserIdField: legacyUserIdField);

  static List<dynamic> _pendingDomain(int uid, {required bool legacyUserIdField}) => _andAll([
        _assigneeLeaf(uid, legacyUserIdField: legacyUserIdField),
        ['active', '=', true],
        ['project_id', '=', false],
        ['parent_id', '=', false],
        ['state', 'not in', _closedStates],
      ]);

  static List<dynamic> _completedDomain(int uid, {required bool legacyUserIdField}) => _andAll([
        _assigneeLeaf(uid, legacyUserIdField: legacyUserIdField),
        ['active', '=', true],
        ['project_id', '=', false],
        ['parent_id', '=', false],
        ['state', 'in', _doneStates],
      ]);

  /// Tasks in a personal To-Do column ([personal_stage_type_ids] contains [stageTypeId]).
  static List<dynamic> _personalColumnDomain(
    int uid,
    int stageTypeId, {
    required bool legacyUserIdField,
  }) =>
      _andAll([
        _assigneeLeaf(uid, legacyUserIdField: legacyUserIdField),
        ['active', '=', true],
        ['project_id', '=', false],
        ['parent_id', '=', false],
        ['personal_stage_type_ids', 'in', [stageTypeId]],
      ]);

  static List<dynamic> _deadlineBetweenDomain(
    int uid,
    DateTime start,
    DateTime end, {
    required bool legacyUserIdField,
  }) =>
      _andAll([
        _assigneeLeaf(uid, legacyUserIdField: legacyUserIdField),
        ['active', '=', true],
        ['project_id', '=', false],
        ['parent_id', '=', false],
        ['date_deadline', '>=', _dateStr(start)],
        ['date_deadline', '<=', _dateStr(end)],
      ]);

  @override
  void onInit() {
    super.onInit();
    ever(_auth.selectedCompanyIds, (_) => loadStats());
    loadStats();
  }

  Future<void> loadStats() async {
    final client = _auth.odooClient;
    final account = _auth.activeAccount.value;
    if (client == null || account == null || account.userId <= 0) {
      return;
    }

    isLoading.value = true;
    loadError.value = null;

    try {
      await _loadAllCounts(client, account.userId, legacyUserIdField: false);
    } on OdooException catch (e) {
      try {
        await _loadAllCounts(client, account.userId, legacyUserIdField: true);
      } catch (_) {
        loadError.value = _formatError(e);
        _zeroCounts();
      }
    } catch (e) {
      loadError.value = _formatError(e);
      _zeroCounts();
    } finally {
      isLoading.value = false;
    }
  }

  String _formatError(Object e) {
    if (e is OdooException) return e.message;
    return e.toString();
  }

  /// Resolves Odoo default personal column types (sequence 2/3/4 = Today / This Week / This Month).
  Future<_PersonalColumnIds?> _resolvePersonalColumnIds(OdooClient client, int uid) async {
    final result = await client.callKw({
      'model': _stageModel,
      'method': 'search_read',
      'args': [
        [
          ['user_id', '=', uid],
        ],
        ['id', 'name', 'sequence'],
      ],
      'kwargs': {
        'order': 'sequence asc',
      },
    });
    if (result is! List || result.isEmpty) return null;

    final rows = result.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) {
        final sa = a['sequence'];
        final sb = b['sequence'];
        final ia = sa is int ? sa : int.tryParse('$sa') ?? 0;
        final ib = sb is int ? sb : int.tryParse('$sb') ?? 0;
        return ia.compareTo(ib);
      });

    int? todayId;
    int? weekId;
    int? monthId;

    for (final row in rows) {
      final id = _asInt(row['id']);
      final seq = row['sequence'];
      final seqInt = seq is int ? seq : int.tryParse('$seq');
      if (id == null) continue;
      if (seqInt == 2) todayId = id;
      if (seqInt == 3) weekId = id;
      if (seqInt == 4) monthId = id;
    }

    if (todayId == null || weekId == null || monthId == null) {
      for (final row in rows) {
        final id = _asInt(row['id']);
        if (id == null) continue;
        final name = (row['name'] as String? ?? '').toLowerCase().trim();
        if (todayId == null && (name == 'today' || name.startsWith('today'))) {
          todayId = id;
        }
        if (weekId == null && (name == 'this week' || name.contains('week'))) {
          weekId = id;
        }
        if (monthId == null && (name == 'this month' || name.contains('month'))) {
          monthId = id;
        }
      }
    }

    if (todayId == null || weekId == null || monthId == null) {
      if (rows.length >= 4) {
        todayId ??= _asInt(rows[1]['id']);
        weekId ??= _asInt(rows[2]['id']);
        monthId ??= _asInt(rows[3]['id']);
      }
    }

    if (todayId == null || weekId == null || monthId == null) return null;
    return _PersonalColumnIds(today: todayId, week: weekId, month: monthId);
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  Future<void> _loadAllCounts(
    OdooClient client,
    int uid, {
    required bool legacyUserIdField,
  }) async {
    countAll.value = await _searchCount(client, _myActiveTasksDomain(uid, legacyUserIdField: legacyUserIdField));
    countPending.value = await _searchCount(client, _pendingDomain(uid, legacyUserIdField: legacyUserIdField));
    countCompleted.value = await _searchCount(client, _completedDomain(uid, legacyUserIdField: legacyUserIdField));

    _PersonalColumnIds? columns;
    try {
      columns = await _resolvePersonalColumnIds(client, uid);
    } catch (_) {
      columns = null;
    }

    if (columns != null) {
      countDueToday.value = await _searchCount(
        client,
        _personalColumnDomain(uid, columns.today, legacyUserIdField: legacyUserIdField),
      );
      countDueThisWeek.value = await _searchCount(
        client,
        _personalColumnDomain(uid, columns.week, legacyUserIdField: legacyUserIdField),
      );
      countDueThisMonth.value = await _searchCount(
        client,
        _personalColumnDomain(uid, columns.month, legacyUserIdField: legacyUserIdField),
      );
    } else {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart;
      final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);

      countDueToday.value = await _searchCount(
        client,
        _deadlineBetweenDomain(uid, todayStart, todayEnd, legacyUserIdField: legacyUserIdField),
      );
      countDueThisWeek.value = await _searchCount(
        client,
        _deadlineBetweenDomain(uid, weekStart, weekEnd, legacyUserIdField: legacyUserIdField),
      );
      countDueThisMonth.value = await _searchCount(
        client,
        _deadlineBetweenDomain(uid, monthStart, monthEnd, legacyUserIdField: legacyUserIdField),
      );
    }
  }

  void _zeroCounts() {
    countAll.value = 0;
    countPending.value = 0;
    countCompleted.value = 0;
    countDueToday.value = 0;
    countDueThisWeek.value = 0;
    countDueThisMonth.value = 0;
  }

  Future<int> _searchCount(OdooClient client, List<dynamic> domain) async {
    final result = await client.callKw({
      'model': _model,
      'method': 'search_count',
      'args': [domain],
      'kwargs': {},
    });
    if (result is int) return result;
    if (result is num) return result.toInt();
    return 0;
  }
}

class _PersonalColumnIds {
  final int today;
  final int week;
  final int month;

  _PersonalColumnIds({required this.today, required this.week, required this.month});
}
