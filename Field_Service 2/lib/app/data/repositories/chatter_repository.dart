import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/storage_service.dart';
import '../providers/api_provider.dart';
import '../../core/utils/logger.dart';

/// Chatter repository — adapted from existing ChatterController
/// but using our FSM app's ApiProvider (JSON-RPC via NetworkService).
class ChatterRepository extends GetxService {
  static ChatterRepository get to => Get.find();

  final ApiProvider _api;
  ChatterRepository(this._api);

  // ── Messages ──────────────────────────────────────────────────────────────

  /// Fetches messages for [model] / [recordId].
  /// Returns list of mail.message maps.
  Future<List<Map<String, dynamic>>> fetchMessages({
    required String model,
    required int recordId,
    int limit = 20,
    int offset = 0,
  }) async {
    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.hasConnection) {
      return _readMessagesCache(model, recordId);
    }
    try {
      final res = await _api.callKw(
        model: 'mail.message',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['model', '=', model],
            <dynamic>['res_id', '=', recordId],
          ],
        ],
        kwargs: <String, dynamic>{
          'fields': <String>[
            'id',
            'body',
            'author_id',
            'date',
            'message_type',
            'subtype_id',
            'author_avatar',
            'email_from',
            // Field-change / stage lines in web chatter (body is often empty).
            'tracking_value_ids',
          ],
          'order': 'id desc',
          'limit': limit,
          'offset': offset,
        },
      );
      if (!res.success || res.data is! List) return _readMessagesCache(model, recordId);
      final list = (res.data as List)
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();
      final enriched = await _enrichMessagesWithTrackingValues(list);
      if (offset == 0) await _saveMessagesCache(model, recordId, enriched);
      return enriched;
    } catch (e) {
      AppLogger.error('fetchMessages error: $e', tag: 'CHATTER');
      return _readMessagesCache(model, recordId);
    }
  }

  /// Odoo stores stage / field changes on `mail.tracking.value`; `body` is often empty.
  Future<List<Map<String, dynamic>>> _enrichMessagesWithTrackingValues(
    List<Map<String, dynamic>> messages,
  ) async {
    final trackingIds = <int>{};
    for (final m in messages) {
      final tv = m['tracking_value_ids'];
      if (tv is! List) continue;
      for (final x in tv) {
        final id = x is int ? x : (x is num ? x.toInt() : int.tryParse(x.toString()));
        if (id != null && id > 0) trackingIds.add(id);
      }
    }
    if (trackingIds.isEmpty) return messages;

    List<dynamic>? rows;
    try {
      final res = await _api.callKw(
        model: 'mail.tracking.value',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['id', 'in', trackingIds.toList()],
          ],
        ],
        kwargs: <String, dynamic>{
          'fields': <String>[
            'id',
            'field_id',
            'old_value_char',
            'new_value_char',
            'old_value_integer',
            'new_value_integer',
            'old_value_float',
            'new_value_float',
            'old_value_datetime',
            'new_value_datetime',
            'old_value_monetary',
            'new_value_monetary',
          ],
          'limit': trackingIds.length,
        },
      );
      if (res.success && res.data is List) rows = res.data as List;
    } catch (_) {
      rows = null;
    }
    rows ??= await _fetchTrackingValuesMinimal(trackingIds);

    if (rows == null) return messages;

    try {
      final byId = <int, Map<String, dynamic>>{};
      for (final e in rows) {
        if (e is! Map) continue;
        final row = Map<String, dynamic>.from(e);
        final id = row['id'];
        final intId = id is int ? id : (id is num ? id.toInt() : int.tryParse(id.toString()));
        if (intId != null) byId[intId] = row;
      }

      for (final m in messages) {
        final tv = m['tracking_value_ids'];
        if (tv is! List) continue;
        final lines = <String>[];
        for (final x in tv) {
          final tid = x is int ? x : (x is num ? x.toInt() : int.tryParse(x.toString()));
          if (tid == null) continue;
          final row = byId[tid];
          if (row == null) continue;
          final line = _formatTrackingValueLine(row);
          if (line.isNotEmpty) lines.add(line);
        }
        if (lines.isNotEmpty) {
          m['_tracking_lines'] = lines;
        }
      }
    } catch (e) {
      AppLogger.warning('tracking values enrich skipped: $e', tag: 'CHATTER');
    }
    return messages;
  }

  Future<List<dynamic>?> _fetchTrackingValuesMinimal(Set<int> trackingIds) async {
    try {
      final res = await _api.callKw(
        model: 'mail.tracking.value',
        method: 'search_read',
        args: <dynamic>[
          <dynamic>[
            <dynamic>['id', 'in', trackingIds.toList()],
          ],
        ],
        kwargs: <String, dynamic>{
          'fields': <String>[
            'id',
            'field_id',
            'old_value_char',
            'new_value_char',
            'old_value_integer',
            'new_value_integer',
          ],
          'limit': trackingIds.length,
        },
      );
      if (res.success && res.data is List) return res.data as List;
    } catch (e) {
      AppLogger.warning('tracking values minimal fetch failed: $e', tag: 'CHATTER');
    }
    return null;
  }

  String _trackingFieldLabel(Map<String, dynamic> row) {
    final f = row['field_id'];
    if (f is List && f.length >= 2) {
      final s = f[1]?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return '';
  }

  String? _trackingSideDisplay(Map<String, dynamic> row, String side) {
    final char = row['${side}_value_char']?.toString().trim();
    if (char != null && char.isNotEmpty) return char;
    final mon = row['${side}_value_monetary'];
    if (mon != null && mon != false) {
      final s = mon.toString().trim();
      if (s.isNotEmpty) return s;
    }
    final fl = row['${side}_value_float'];
    if (fl is num) return fl.toString();
    if (fl != null && fl != false) {
      final s = fl.toString().trim();
      if (s.isNotEmpty) return s;
    }
    final dt = row['${side}_value_datetime'];
    if (dt != null && dt != false) {
      final s = dt.toString().trim();
      if (s.isNotEmpty) return s;
    }
    final iv = row['${side}_value_integer'];
    if (iv != null && iv != false) {
      if (iv is int) return iv.toString();
      if (iv is num) return iv.toString();
    }
    return null;
  }

  String _formatTrackingValueLine(Map<String, dynamic> row) {
    final oldV = _trackingSideDisplay(row, 'old');
    final newV = _trackingSideDisplay(row, 'new');
    final field = _trackingFieldLabel(row);
    if ((oldV == null || oldV.isEmpty) && (newV == null || newV.isEmpty)) {
      return '';
    }
    final oldDisp = oldV ?? '';
    final newDisp = newV ?? '';
    final arrow = ' → ';
    final core = '$oldDisp$arrow$newDisp';
    if (field.isNotEmpty) return '$core ($field)';
    return core;
  }

  /// Sends a message (comment) or log note (notification) on [model]/[recordId].
  Future<bool> postMessage({
    required String model,
    required int recordId,
    required String body,
    bool isNote = false,
  }) async {
    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.hasConnection) {
      await _enqueuePendingMessage(model: model, recordId: recordId, body: body, isNote: isNote);
      return true; // Optimistic — will sync when online
    }
    try {
      final res = await _api.callKw(
        model: model,
        method: 'message_post',
        args: <dynamic>[<int>[recordId]],
        kwargs: <String, dynamic>{
          'body': body,
          'message_type': 'comment',
          'subtype_xmlid': isNote ? 'mail.mt_note' : 'mail.mt_comment',
        },
      );
      if (!res.success) {
        AppLogger.error('postMessage failed: ${res.error}', tag: 'CHATTER');
        return false;
      }
      return res.data != null;
    } catch (e) {
      // Network failure — queue
      await _enqueuePendingMessage(model: model, recordId: recordId, body: body, isNote: isNote);
      return true;
    }
  }

  /// Fetches clean partner names by ids — avoids display_name with company prefix.
  Future<Map<int, String>> fetchPartnerNames(List<int> partnerIds) async {
    if (partnerIds.isEmpty) return {};
    final res = await _api.callKw(
      model: 'res.partner',
      method: 'search_read',
      args: <dynamic>[
        <dynamic>[<dynamic>['id', 'in', partnerIds]],
      ],
      kwargs: const <String, dynamic>{
        'fields': <String>['id', 'name'],
        'limit': 100,
      },
    );
    if (!res.success || res.data is! List) return {};
    final map = <int, String>{};
    for (final row in res.data as List) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final id = m['id'];
      final name = m['name']?.toString() ?? '';
      if (id is int && name.isNotEmpty) map[id] = name;
    }
    return map;
  }

  // ── Activities ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchActivities({
    required String model,
    required int recordId,
  }) async {
    final res = await _api.callKw(
      model: 'mail.activity',
      method: 'search_read',
      args: <dynamic>[
        <dynamic>[
          <dynamic>['res_model', '=', model],
          <dynamic>['res_id', '=', recordId],
        ],
      ],
      kwargs: const <String, dynamic>{
        'fields': <String>[
          'id', 'activity_type_id', 'summary',
          'note', 'date_deadline', 'user_id', 'state',
        ],
        'order': 'date_deadline asc',
      },
    );
    if (!res.success || res.data is! List) return [];
    return (res.data as List)
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchActivityTypes() async {
    final res = await _api.callKw(
      model: 'mail.activity.type',
      method: 'search_read',
      args: const <dynamic>[<dynamic>[]],
      kwargs: const <String, dynamic>{
        'fields': <String>['id', 'name'],
        'order': 'sequence',
        'limit': 100,
      },
    );
    if (!res.success || res.data is! List) return [];
    return (res.data as List)
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final res = await _api.callKw(
      model: 'res.users',
      method: 'search_read',
      args: <dynamic>[
        <dynamic>[<dynamic>['active', '=', true]],
      ],
      kwargs: const <String, dynamic>{
        'fields': <String>['id', 'name'],
        'order': 'name',
        'limit': 200,
      },
    );
    if (!res.success || res.data is! List) return [];
    return (res.data as List)
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<int?> fetchModelId(String modelName) async {
    final res = await _api.callKw(
      model: 'ir.model',
      method: 'search_read',
      args: <dynamic>[
        <dynamic>[<dynamic>['model', '=', modelName]],
      ],
      kwargs: const <String, dynamic>{
        'fields': <String>['id'],
        'limit': 1,
      },
    );
    if (!res.success || res.data is! List) return null;
    final rows = res.data as List;
    if (rows.isEmpty || rows.first is! Map) return null;
    final id = Map<String, dynamic>.from(rows.first as Map)['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse(id.toString());
  }

  Future<bool> scheduleActivity({
    required String model,
    required int recordId,
    required int activityTypeId,
    required DateTime deadline,
    String? summary,
    String? note,
    int? userId,
  }) async {
    final modelId = await fetchModelId(model);
    if (modelId == null) return false;

    final data = <String, dynamic>{
      'res_model_id': modelId,
      'res_model': model,
      'res_id': recordId,
      'activity_type_id': activityTypeId,
      'date_deadline': deadline.toIso8601String().split('T')[0],
      if (summary != null && summary.isNotEmpty) 'summary': summary,
      if (note != null && note.isNotEmpty) 'note': note,
      if (userId != null) 'user_id': userId,
    };

    final res = await _api.callKw(
      model: 'mail.activity',
      method: 'create',
      args: <dynamic>[data],
      kwargs: const <String, dynamic>{},
    );
    return res.success && res.data != null;
  }

  /// Dashboard-level activities for current user.
  Future<List<Map<String, dynamic>>> fetchMyActivities({int? userId}) async {
    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.hasConnection) return const <Map<String, dynamic>>[];
    final res = await _api.callKw(
      model: 'mail.activity',
      method: 'search_read',
        args: const <dynamic>[
          <dynamic>[],
        ],
      kwargs: const <String, dynamic>{
        'fields': <String>[
          'id',
          'res_name',
          'res_model',
          'res_id',
          'activity_type_id',
          'summary',
          'date_deadline',
          'user_id',
          'note',
          'state',
          'create_date',
          'write_date',
        ],
        'order': 'date_deadline asc, id desc',
        'limit': 500,
      },
    );
    if (!res.success || res.data is! List) return const <Map<String, dynamic>>[];
    return (res.data as List)
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<bool> markActivityDone(int id) async {
    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.hasConnection) return false;
    final res = await _api.callKw(
      model: 'mail.activity',
      method: 'action_done',
      args: <dynamic>[
        <dynamic>[id]
      ],
      kwargs: const <String, dynamic>{},
    );
    return res.success;
  }

  Future<bool> cancelActivity(int id) async {
    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.hasConnection) return false;
    final res = await _api.callKw(
      model: 'mail.activity',
      method: 'unlink',
      args: <dynamic>[
        <dynamic>[id]
      ],
      kwargs: const <String, dynamic>{},
    );
    return res.success;
  }

  static const String _chatBoxName = 'fsm_chatter';

  String _chatScope() {
    var db = '';
    if (Get.isRegistered<StorageService>()) {
      db = Get.find<StorageService>().selectedDb.trim().toLowerCase();
    }
    return db;
  }

  String _messagesCacheKey(String model, int recordId) =>
      '${_chatScope()}::messages_${model}_$recordId';

  String get _pendingMessagesKey => '${_chatScope()}::pending_messages';

  Future<Box<dynamic>> _openChatBox() async {
    return Hive.openBox<dynamic>(_chatBoxName);
  }

  Future<void> _saveMessagesCache(String model, int recordId, List<Map<String, dynamic>> list) async {
    try {
      final box = await _openChatBox();
      await box.put(_messagesCacheKey(model, recordId), list);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _readMessagesCache(String model, int recordId) async {
    try {
      final box = await _openChatBox();
      final raw = box.get(_messagesCacheKey(model, recordId));
      if (raw is List) {
        return raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _enqueuePendingMessage({
    required String model,
    required int recordId,
    required String body,
    required bool isNote,
  }) async {
    try {
      final box = await _openChatBox();
      final raw = box.get(_pendingMessagesKey);
      final list = raw is List ? List<Map<String, dynamic>>.from(
        raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
      ) : <Map<String, dynamic>>[];
      list.add({
        'model': model,
        'recordId': recordId,
        'body': body,
        'isNote': isNote,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      await box.put(_pendingMessagesKey, list);
      AppLogger.info('Queued offline chatter message for $model/$recordId', tag: 'CHATTER');
    } catch (_) {}
  }

  /// Call this when connectivity is restored.
  Future<void> syncPendingMessages() async {
    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.hasConnection) return;
    try {
      final box = await _openChatBox();
      final raw = box.get(_pendingMessagesKey);
      if (raw is! List || raw.isEmpty) return;
      final jobs = List<Map<String, dynamic>>.from(
        raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
      );
      final remaining = <Map<String, dynamic>>[];
      for (final job in jobs) {
        try {
          final res = await _api.callKw(
            model: job['model'] as String,
            method: 'message_post',
            args: <dynamic>[<int>[job['recordId'] as int]],
            kwargs: <String, dynamic>{
              'body': job['body'] as String,
              'message_type': 'comment',
              'subtype_xmlid': (job['isNote'] as bool? ?? false)
                  ? 'mail.mt_note' : 'mail.mt_comment',
            },
          );
          if (!res.success) remaining.add(job);
        } catch (_) {
          remaining.add(job);
        }
      }
      await box.put(_pendingMessagesKey, remaining);
    } catch (e) {
      AppLogger.error('syncPendingMessages error: $e', tag: 'CHATTER');
    }
  }

}