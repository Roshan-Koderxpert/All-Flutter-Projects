import 'package:get/get.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import 'login_controller.dart';

enum TodoTaskFilter { all, pending, completed }

class TodoTaskRow {
  final int id;
  final String name;
  final List<String> assignees;
  final String activityIcon;
  final String state;

  TodoTaskRow({
    required this.id,
    required this.name,
    required this.assignees,
    required this.activityIcon,
    required this.state,
  });
}

/// Loads the same task set as Odoo **To-dos**:
/// `user_ids in uid`, `project_id = False`, `parent_id = False`.
class TodoTasksController extends GetxController {
  final AuthController _auth = Get.find<AuthController>();

  final isLoading = false.obs;
  final loadError = RxnString();

  final _allTasks = <TodoTaskRow>[].obs;
  final tasks = <TodoTaskRow>[].obs; // visible tasks after search/filter

  final query = ''.obs;
  final filter = TodoTaskFilter.all.obs;

  static const String _model = 'project.task';
  static const String _userModel = 'res.users';
  static const String _activityModel = 'mail.activity';
  static const String _activityTypeModel = 'mail.activity.type';

  static const String _stateDone = '1_done';
  static const String _stateCanceled = '1_canceled';

  @override
  void onInit() {
    super.onInit();
    ever(_auth.selectedCompanyIds, (_) => loadTasks());
    loadTasks();
  }

  int get visibleCount => tasks.length;
  int get totalCount => _allTasks.length;

  void setQuery(String q) {
    query.value = q;
    _applySearchAndFilter();
  }

  void setFilter(TodoTaskFilter f) {
    filter.value = f;
    _applySearchAndFilter();
  }

  void clearAll() {
    query.value = '';
    filter.value = TodoTaskFilter.all;
    _applySearchAndFilter();
  }

  Future<void> loadTasks() async {
    final client = _auth.odooClient;
    final account = _auth.activeAccount.value;
    if (client == null || account == null || account.userId <= 0) return;

    isLoading.value = true;
    loadError.value = null;

    try {
      final result = await client.callKw({
        'model': _model,
        'method': 'search_read',
        'args': [
          [
            ['user_ids', 'in', [account.userId]],
            ['project_id', '=', false],
            ['parent_id', '=', false],
            ['active', '=', true],
          ],
          ['id', 'name', 'user_ids', 'state'],
        ],
        'kwargs': {
          'order': 'id desc',
          'limit': 80,
        },
      });

      final rows = (result is List) ? result : const [];
      final rawTasks = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final userIds = <int>{};
      for (final t in rawTasks) {
        final ids = _parseMany2ManyIds(t['user_ids']);
        userIds.addAll(ids);
      }
      final userNames = await _loadUserNames(client, userIds.toList());

      final taskIds = rawTasks.map((t) => (t['id'] as num?)?.toInt() ?? 0).where((e) => e > 0).toList();
      final taskIconMap = await _loadTaskActivityIcons(client, taskIds);

      _allTasks.assignAll(rawTasks.map((m) {
        final ids = _parseMany2ManyIds(m['user_ids']);
        final id = (m['id'] as num?)?.toInt() ?? 0;
        return TodoTaskRow(
          id: id,
          name: (m['name'] as String?) ?? '',
          assignees: ids.map((id) => userNames[id] ?? '').where((n) => n.isNotEmpty).toList(),
          activityIcon: taskIconMap[id] ?? '',
          state: (m['state'] as String?) ?? '',
        );
      }));
      _applySearchAndFilter();
    } on OdooException catch (e) {
      loadError.value = e.message;
      _allTasks.clear();
      tasks.clear();
    } catch (e) {
      loadError.value = e.toString();
      _allTasks.clear();
      tasks.clear();
    } finally {
      isLoading.value = false;
    }
  }

  bool _matchesFilter(TodoTaskRow t) {
    switch (filter.value) {
      case TodoTaskFilter.all:
        return true;
      case TodoTaskFilter.completed:
        return t.state == _stateDone;
      case TodoTaskFilter.pending:
        return t.state != _stateDone && t.state != _stateCanceled;
    }
  }

  void _applySearchAndFilter() {
    final q = query.value.trim().toLowerCase();
    final filtered = _allTasks.where((t) {
      if (!_matchesFilter(t)) return false;
      if (q.isEmpty) return true;
      final assignees = t.assignees.join(' ').toLowerCase();
      return t.name.toLowerCase().contains(q) || assignees.contains(q);
    }).toList();
    tasks.assignAll(filtered);
  }

  List<int> _parseMany2ManyIds(dynamic v) {
    if (v is List) {
      return v.map((e) => (e as num?)?.toInt() ?? 0).where((e) => e > 0).toList();
    }
    return const [];
  }

  Future<Map<int, String>> _loadUserNames(OdooClient client, List<int> ids) async {
    if (ids.isEmpty) return {};
    final result = await client.callKw({
      'model': _userModel,
      'method': 'search_read',
      'args': [
        [
          ['id', 'in', ids],
        ],
        ['id', 'name'],
      ],
      'kwargs': {},
    });
    final rows = (result is List) ? result : const [];
    final map = <int, String>{};
    for (final e in rows) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = (m['id'] as num?)?.toInt();
      final name = (m['name'] as String?) ?? '';
      if (id != null && name.isNotEmpty) map[id] = name;
    }
    return map;
  }

  Future<Map<int, String>> _loadTaskActivityIcons(OdooClient client, List<int> taskIds) async {
    if (taskIds.isEmpty) return {};

    final activityResult = await client.callKw({
      'model': _activityModel,
      'method': 'search_read',
      'args': [
        [
          ['res_model', '=', 'project.task'],
          ['res_id', 'in', taskIds],
        ],
        ['id', 'res_id', 'activity_type_id'],
      ],
      'kwargs': {
        'order': 'id desc',
        'limit': 500,
      },
    });
    final activityRows = (activityResult is List) ? activityResult : const [];

    final taskToTypeId = <int, int>{};
    final typeIds = <int>{};
    for (final e in activityRows) {
      final m = Map<String, dynamic>.from(e as Map);
      final resId = (m['res_id'] as num?)?.toInt() ?? 0;
      if (resId <= 0 || taskToTypeId.containsKey(resId)) continue;
      final typePair = m['activity_type_id'];
      if (typePair is List && typePair.isNotEmpty) {
        final typeId = (typePair[0] as num?)?.toInt() ?? 0;
        if (typeId > 0) {
          taskToTypeId[resId] = typeId;
          typeIds.add(typeId);
        }
      }
    }

    if (typeIds.isEmpty) return {};

    final typeResult = await client.callKw({
      'model': _activityTypeModel,
      'method': 'search_read',
      'args': [
        [
          ['id', 'in', typeIds.toList()],
        ],
        ['id', 'icon'],
      ],
      'kwargs': {},
    });
    final typeRows = (typeResult is List) ? typeResult : const [];
    final typeIdToIcon = <int, String>{};
    for (final e in typeRows) {
      final m = Map<String, dynamic>.from(e as Map);
      final typeId = (m['id'] as num?)?.toInt();
      final icon = (m['icon'] as String?) ?? '';
      if (typeId != null) typeIdToIcon[typeId] = icon;
    }

    final taskToIcon = <int, String>{};
    taskToTypeId.forEach((taskId, typeId) {
      taskToIcon[taskId] = typeIdToIcon[typeId] ?? '';
    });
    return taskToIcon;
  }
}

