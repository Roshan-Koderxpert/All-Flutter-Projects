import 'package:odoo_rpc/odoo_rpc.dart';

import '../../core/utils/api_logger.dart';
import '../models/timesheet_line.dart';

class TimesheetRepository {
  TimesheetRepository(this._client);

  final OdooClient _client;

  /// Whether a failure means the server simply doesn't have that field/model.
  ///
  /// Odoo raises `Invalid field ...` / `KeyError` when a module that defines
  /// the field isn't installed — on such a server no alternative domain can
  /// succeed, so callers should stop retrying instead of firing the same
  /// doomed request several more times.
  static bool _isMissingSchema(Object e) {
    final message = e.toString();
    return message.contains('Invalid field') ||
        message.contains('KeyError') ||
        message.contains('does not exist');
  }

  static const _lineFields = [
    'id',
    'date',
    'name',
    'unit_amount',
    'amount',
    'project_id',
    'task_id',
  ];

  Future<List<TimesheetProjectOption>> fetchTimesheetProjects() async {
    ApiLogger.info('--- TimesheetRepository.fetchTimesheetProjects ---');

    for (final domain in [
      [
        ['allow_timesheets', '=', true],
        ['active', '=', true],
      ],
      [
        ['allow_timesheets', '=', true],
      ],
      [],
    ]) {
      try {
        final result = await _client.callKw({
          'model': 'project.project',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': ['id', 'name'],
            'order': 'name asc',
            'limit': 500,
          },
        });
        if (result is! List || result.isEmpty) continue;

        return result
            .map((raw) {
              final map = Map<String, dynamic>.from(raw as Map);
              return TimesheetProjectOption(
                id: map['id'] as int,
                name: map['name']?.toString() ?? 'Project',
              );
            })
            .toList();
      } catch (e, st) {
        if (_isMissingSchema(e)) {
          // `allow_timesheets` is added by hr_timesheet. If it isn't there the
          // module isn't installed, and the remaining domains will fail the
          // same way — retrying only costs round-trips and log noise.
          ApiLogger.info(
            'fetchTimesheetProjects: hr_timesheet not installed — $e',
          );
          break;
        }
        ApiLogger.error('fetchTimesheetProjects domain=$domain', e, st);
      }
    }
    return [];
  }

  Future<List<TimesheetTaskOption>> fetchTasksForProject(int projectId) async {
    ApiLogger.info(
      '--- TimesheetRepository.fetchTasksForProject proj=$projectId ---',
    );

    for (final domain in [
      [
        ['project_id', '=', projectId],
        ['display_in_project', '=', true],
      ],
      [
        ['project_id', '=', projectId],
      ],
    ]) {
      try {
        final result = await _client.callKw({
          'model': 'project.task',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': ['id', 'name'],
            'order': 'name asc',
            'limit': 500,
          },
        });
        if (result is! List) continue;
        return result
            .map((raw) {
              final map = Map<String, dynamic>.from(raw as Map);
              return TimesheetTaskOption(
                id: map['id'] as int,
                name: map['name']?.toString() ?? 'Task',
              );
            })
            .toList();
      } catch (e, st) {
        ApiLogger.error('fetchTasksForProject domain=$domain', e, st);
      }
    }
    return [];
  }

  Future<List<TimesheetLine>> fetchMyTimesheets({
    required int employeeId,
    int? userId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 200,
  }) async {
    ApiLogger.info(
      '--- TimesheetRepository.fetchMyTimesheets emp=$employeeId user=$userId ---',
    );
    if (dateFrom != null || dateTo != null) {
      ApiLogger.json(
        'date range',
        '${dateFrom != null ? _toDateOnly(dateFrom) : '…'} → '
        '${dateTo != null ? _toDateOnly(dateTo) : '…'}',
      );
    }

    final dateFilters = <List<dynamic>>[];
    if (dateFrom != null) {
      dateFilters.add(['date', '>=', _toDateOnly(dateFrom)]);
    }
    if (dateTo != null) {
      dateFilters.add(['date', '<=', _toDateOnly(dateTo)]);
    }

    final domains = <List<dynamic>>[
      [
        ['employee_id', '=', employeeId],
        ...dateFilters,
      ],
      if (userId != null)
        [
          ['user_id', '=', userId],
          ...dateFilters,
        ],
      [
        ['employee_id', '=', employeeId],
        ['project_id', '!=', false],
        ...dateFilters,
      ],
      if (userId != null)
        [
          ['user_id', '=', userId],
          ['project_id', '!=', false],
          ...dateFilters,
        ],
    ];

    final context = {
      'default_employee_id': employeeId,
      if (userId != null) 'default_user_id': userId,
    };

    List<TimesheetLine> best = const [];

    for (final domain in domains) {
      try {
        final result = await _client.callKw({
          'model': 'account.analytic.line',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': _lineFields,
            'order': 'date desc, id desc',
            'limit': limit,
            'context': context,
          },
        });
        if (result is! List) continue;

        final lines = result
            .map((raw) =>
                TimesheetLine.fromOdoo(Map<String, dynamic>.from(raw as Map)))
            .toList();

        ApiLogger.info(
          'fetchMyTimesheets domain=$domain => ${lines.length} lines',
        );

        if (lines.isNotEmpty) return lines;
        if (lines.length > best.length) best = lines;
      } catch (e, st) {
        if (_isMissingSchema(e)) {
          ApiLogger.info(
            'fetchMyTimesheets: timesheets unavailable on this server '
            '(hr_timesheet not installed) — $e',
          );
          return const [];
        }
        ApiLogger.error('fetchMyTimesheets domain=$domain', e, st);
      }
    }

    if (best.isEmpty) {
      ApiLogger.info('fetchMyTimesheets: no lines for any domain');
    }
    return best;
  }

  Future<int?> createTimesheet({
    required int employeeId,
    int? userId,
    required int projectId,
    int? taskId,
    required DateTime date,
    required double hours,
    required String description,
  }) async {
    ApiLogger.info('--- TimesheetRepository.createTimesheet ---');

    final dateStr = _toDateOnly(date);
    final desc = description.trim().isNotEmpty ? description.trim() : '/';

    final base = <String, dynamic>{
      'name': desc,
      'date': dateStr,
      'unit_amount': hours,
      'project_id': projectId,
      if (taskId != null) 'task_id': taskId,
    };

    final valueSets = <Map<String, dynamic>>[
      {...base, 'employee_id': employeeId},
      if (userId != null) {...base, 'employee_id': employeeId, 'user_id': userId},
      if (userId != null) {...base, 'user_id': userId},
      base,
    ];

    Object? lastError;
    for (final values in valueSets) {
      try {
        final id = await _client.callKw({
          'model': 'account.analytic.line',
          'method': 'create',
          'args': [values],
          'kwargs': {
            'context': {
              'default_project_id': projectId,
              if (taskId != null) 'default_task_id': taskId,
              'default_employee_id': employeeId,
            },
          },
        });
        if (id is int) return id;
      } catch (e, st) {
        lastError = e;
        ApiLogger.error('createTimesheet values=$values', e, st);
      }
    }
    throw Exception('Could not save timesheet. ${lastError ?? ''}');
  }

  Future<void> updateTimesheet({
    required int lineId,
    required double hours,
    required String description,
    DateTime? date,
    int? projectId,
    int? taskId,
  }) async {
    ApiLogger.info('--- TimesheetRepository.updateTimesheet id=$lineId ---');

    final desc = description.trim().isNotEmpty ? description.trim() : '/';
    final values = <String, dynamic>{
      'name': desc,
      'unit_amount': hours,
    };
    if (date != null) values['date'] = _toDateOnly(date);
    if (projectId != null) values['project_id'] = projectId;
    if (taskId != null) values['task_id'] = taskId;

    await _client.callKw({
      'model': 'account.analytic.line',
      'method': 'write',
      'args': [
        [lineId],
        values,
      ],
      'kwargs': {},
    });
  }

  String _toDateOnly(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
