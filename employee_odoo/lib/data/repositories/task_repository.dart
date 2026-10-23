import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/task_record.dart';
import '../../core/utils/api_logger.dart';

class TaskModuleUnavailable implements Exception {}

class TaskStage {
  final int id;
  final String name;
  TaskStage({required this.id, required this.name});
}

class TaskRepository {
  final OdooClient _client;
  TaskRepository(this._client);

  // Same field list already proven in task_notification_sheet.dart,
  // plus personal_stage_type_id — the field Odoo's own "My Tasks" view
  // groups by (Inbox/Today/This Week/etc.), not the project's stage_id.
  static const _fields = [
    'id', 'name', 'project_id', 'date_deadline', 'priority', 'description', 'personal_stage_type_id',
  ];

  bool _isMissingModelError(Object e) {
    final msg = e.toString();
    return msg.contains('project.task') &&
        (msg.contains('KeyError') || msg.contains('404') || msg.contains('Not Found'));
  }

  /// Tasks assigned to the logged-in user. project.task uses 'user_ids'
  /// (many2many) in Odoo 16+, so we filter on the res.users id, not the
  /// employee id.
  Future<List<TaskRecord>> fetchMine(int userId) async {
    try {
      final result = await _client.callKw({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [['user_ids', 'in', [userId]]],
        ],
        'kwargs': {'fields': _fields, 'order': 'date_deadline asc, id desc'},
      });
      if (result is! List) return [];
      return result
          .map((e) => TaskRecord.fromOdoo(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      if (_isMissingModelError(e)) throw TaskModuleUnavailable();
      ApiLogger.error('TaskRepository.fetchMine failed', e, st);
      return [];
    }
  }

  Future<TaskRecord?> fetchById(int id) async {
    try {
      final result = await _client.callKw({
        'model': 'project.task',
        'method': 'search_read',
        'args': [
          [['id', '=', id]],
        ],
        'kwargs': {'fields': _fields, 'limit': 1},
      });
      if (result is! List || result.isEmpty) return null;
      return TaskRecord.fromOdoo(Map<String, dynamic>.from(result.first as Map));
    } catch (e, st) {
      if (_isMissingModelError(e)) throw TaskModuleUnavailable();
      ApiLogger.error('TaskRepository.fetchById id=$id failed', e, st);
      return null;
    }
  }

  /// The exact columns Odoo's own "My Tasks" kanban shows (Inbox, Today,
  /// This Week, This Month, Later, Done, Cancelled by default) — these are
  /// project.task.type records scoped to this user via 'user_id', not
  /// project-level kanban stages. Odoo auto-creates the default set the
  /// first time a user opens My Tasks in the web UI.
  Future<List<TaskStage>> fetchPersonalStages(int userId) async {
    try {
      final result = await _client.callKw({
        'model': 'project.task.type',
        'method': 'search_read',
        'args': [
          [['user_id', '=', userId]],
        ],
        'kwargs': {'fields': ['id', 'name'], 'order': 'sequence asc'},
      });
      if (result is! List) return [];
      return result
          .map((e) => TaskStage(
        id: (e as Map)['id'] as int,
        name: e['name'] as String? ?? '',
      ))
          .toList();
    } catch (e, st) {
      ApiLogger.error('TaskRepository.fetchPersonalStages failed', e, st);
      return [];
    }
  }

  /// Moves a task between personal stage columns (e.g. Inbox -> Today).
  Future<bool> updateStage(int taskId, int stageId) async {
    try {
      await _client.callKw({
        'model': 'project.task',
        'method': 'write',
        'args': [
          [taskId],
          {'personal_stage_type_id': stageId},
        ],
        'kwargs': {},
      });
      return true;
    } catch (e, st) {
      ApiLogger.error('TaskRepository.updateStage id=$taskId failed', e, st);
      return false;
    }
  }
}