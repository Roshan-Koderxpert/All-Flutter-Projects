import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import 'login_controller.dart';

class TodoActivityRow {
  final int id;
  final int taskId;
  final int typeId;
  final String typeName;
  final String summary;
  final String taskName;
  final String assignedTo;
  final DateTime? createdAt;
  final DateTime? deadlineAt;
  final String status; // overdue / today / planned

  TodoActivityRow({
    required this.id,
    required this.taskId,
    required this.typeId,
    required this.typeName,
    required this.summary,
    required this.taskName,
    required this.assignedTo,
    required this.createdAt,
    required this.deadlineAt,
    required this.status,
  });
}

/// Fetches Odoo activities (`mail.activity`) for project.task records,
/// and pulls icon metadata from `mail.activity.type`.
class TodoActivityController extends GetxController {
  final AuthController _auth = Get.find<AuthController>();

  final isLoading = false.obs;
  final loadError = RxnString();

  final activities = <TodoActivityRow>[].obs;

  final _typeIdToIcon = <int, String>{}.obs; // e.g. "fa-phone"

  static const String _model = 'mail.activity';
  static const String _typeModel = 'mail.activity.type';

  @override
  void onInit() {
    super.onInit();
    ever(_auth.selectedCompanyIds, (_) => loadActivities());
    loadActivities();
  }

  Future<void> loadActivities() async {
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
            ['res_model', '=', 'project.task'],
          ],
          [
            'id',
            'res_id',
            'summary',
            'res_name',
            'activity_type_id',
            'user_id',
            'create_date',
            'date_deadline',
          ],
        ],
        'kwargs': {
          'order': 'date_deadline asc, id desc',
          'limit': 80,
        },
      });

      final rows = (result is List) ? result : const [];

      final parsed = <TodoActivityRow>[];
      final typeIds = <int>{};

      for (final e in rows) {
        final m = Map<String, dynamic>.from(e as Map);
        final typePair = m['activity_type_id'];
        int typeId = 0;
        String typeName = '';
        if (typePair is List && typePair.isNotEmpty) {
          typeId = (typePair[0] as num?)?.toInt() ?? 0;
          typeName = (typePair.length > 1 ? typePair[1] : '')?.toString() ?? '';
        }
        final userPair = m['user_id'];
        String assignedTo = '';
        if (userPair is List && userPair.length > 1) {
          assignedTo = (userPair[1] ?? '').toString();
        }

        final createdAt = _parseDate(m['create_date']);
        final deadlineAt = _parseDate(m['date_deadline']);
        final status = _deriveStatus(deadlineAt);

        if (typeId > 0) typeIds.add(typeId);
        parsed.add(TodoActivityRow(
          id: (m['id'] as num?)?.toInt() ?? 0,
          taskId: (m['res_id'] as num?)?.toInt() ?? 0,
          typeId: typeId,
          typeName: typeName.isEmpty ? 'Activity' : typeName,
          summary: (m['summary'] as String?) ?? '',
          taskName: (m['res_name'] as String?) ?? '',
          assignedTo: assignedTo,
          createdAt: createdAt,
          deadlineAt: deadlineAt,
          status: status,
        ));
      }

      activities.assignAll(parsed);
      await _loadTypeIcons(client, typeIds.toList());
    } on OdooException catch (e) {
      loadError.value = e.message;
      activities.clear();
      _typeIdToIcon.clear();
    } catch (e) {
      loadError.value = e.toString();
      activities.clear();
      _typeIdToIcon.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadTypeIcons(OdooClient client, List<int> typeIds) async {
    if (typeIds.isEmpty) return;

    final result = await client.callKw({
      'model': _typeModel,
      'method': 'search_read',
      'args': [
        [
          ['id', 'in', typeIds],
        ],
        ['id', 'icon'],
      ],
      'kwargs': {},
    });

    final rows = (result is List) ? result : const [];
    final map = <int, String>{};
    for (final e in rows) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = (m['id'] as num?)?.toInt();
      final icon = (m['icon'] as String?) ?? '';
      if (id != null && icon.isNotEmpty) {
        map[id] = icon;
      }
    }
    _typeIdToIcon.assignAll(map);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'false') return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  String _deriveStatus(DateTime? deadline) {
    if (deadline == null) return 'planned';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(deadline.year, deadline.month, deadline.day);
    if (d.isBefore(today)) return 'overdue';
    if (d.isAtSameMomentAs(today)) return 'today';
    return 'planned';
  }

  Future<void> markAsDone(TodoActivityRow row) async {
    final client = _auth.odooClient;
    if (client == null) return;
    try {
      await client.callKw({
        'model': _model,
        'method': 'action_done',
        'args': [
          [row.id],
        ],
        'kwargs': {},
      });
      await loadActivities();
    } catch (_) {
      // Fallback used by some versions/customizations
      await client.callKw({
        'model': _model,
        'method': 'action_feedback',
        'args': [
          [row.id],
        ],
        'kwargs': {'feedback': ''},
      });
      await loadActivities();
    }
  }

  Future<void> cancelActivity(TodoActivityRow row) async {
    final client = _auth.odooClient;
    if (client == null) return;
    await client.callKw({
      'model': _model,
      'method': 'unlink',
      'args': [
        [row.id],
      ],
      'kwargs': {},
    });
    await loadActivities();
  }

  IconData iconForActivity(TodoActivityRow a) {
    final s = (_typeIdToIcon[a.typeId] ?? '').toLowerCase();
    if (s.contains('phone')) return Icons.call_outlined;
    if (s.contains('envelope') || s.contains('mail')) return Icons.email_outlined;
    if (s.contains('check')) return Icons.task_alt_outlined;
    if (s.contains('calendar')) return Icons.event_outlined;
    if (s.contains('clock')) return Icons.schedule_outlined;
    return Icons.notifications_none_outlined;
  }
}

