import 'dart:async';
import 'package:get/get.dart';
import '../../../core/utils/api_logger.dart';
import '../../auth/controllers/auth_controller.dart';

class ChatterConversation {
  final int id;
  final String name;
  final String channelType; // 'chat' (1:1) or 'channel' (group)
  final int unreadCount;
  final String? imageBase64;

  ChatterConversation({
    required this.id,
    required this.name,
    required this.channelType,
    this.unreadCount = 0,
    this.imageBase64,
  });

  bool get isDirect => channelType == 'chat';
}

class ChatterMessage {
  final int id;
  final String body;
  final String authorName;
  final int? authorId;
  final DateTime? date;
  final bool isMine;

  ChatterMessage({
    required this.id,
    required this.body,
    required this.authorName,
    this.authorId,
    this.date,
    required this.isMine,
  });
}

class MailboxMessage {
  final int id;
  final String body;
  final String authorName;
  final String? recordName;
  final String model;
  final int resId;
  final DateTime? date;

  MailboxMessage({
    required this.id,
    required this.body,
    required this.authorName,
    this.recordName,
    required this.model,
    required this.resId,
    this.date,
  });

  /// Only messages posted on a discuss.channel can be opened as a chat
  /// thread in this app — other business-record messages (e.g. on an
  /// expense or task) aren't rendered here yet.
  bool get isChannelMessage => model == 'discuss.channel';
}

class ChatterController extends GetxController {
  late final AuthController _auth;

  final conversations = <ChatterConversation>[].obs;
  final isLoadingConversations = false.obs;

  final threadMessages = <ChatterMessage>[].obs;
  final isLoadingThread = false.obs;
  final isSending = false.obs;

  final inboxCount = 0.obs;
  final starredCount = 0.obs;
  final historyCount = 0.obs;

  bool _unreadFieldSupported = true;
  Timer? _listPollTimer;
  Timer? _threadPollTimer;
  int _openChannelId = 0;
  int _lastMessageId = 0;
  int? _myPartnerId;

  @override
  void onInit() {
    super.onInit();
    _auth = Get.find<AuthController>();
  }

  @override
  void onClose() {
    _listPollTimer?.cancel();
    _threadPollTimer?.cancel();
    super.onClose();
  }

  /// mail.message.author_id is a res.partner reference — not the same as
  /// the res.users id already stored on the account. Resolved once and
  /// cached so every message bubble can be correctly marked sent/received.
  Future<int?> _ensureMyPartnerId() async {
    if (_myPartnerId != null) return _myPartnerId;
    final uid = _auth.activeAccount.value?.userId;
    if (uid == null) return null;
    _myPartnerId = await _resolvePartnerForUser(uid);
    return _myPartnerId;
  }

  final Map<int, int?> _userPartnerCache = {};

  /// Generalized version of the above — resolves ANY res.users id to its
  /// res.partner id (needed to start a chat with an employee, since
  /// discuss.channel.channel_get expects partner ids, not employee or
  /// user ids). Cached per user id so browsing the employee picker
  /// doesn't refetch the same person repeatedly.
  Future<int?> _resolvePartnerForUser(int userId) async {
    if (_userPartnerCache.containsKey(userId)) return _userPartnerCache[userId];
    final client = _auth.odooClient;
    if (client == null) return null;
    try {
      final result = await client
          .callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          ['partner_id'],
        ],
        'kwargs': {},
      })
          .timeout(const Duration(seconds: 15));
      int? partnerId;
      if (result is List && result.isNotEmpty) {
        final row = Map<String, dynamic>.from(result.first as Map);
        final partnerField = row['partner_id'];
        if (partnerField is List && partnerField.isNotEmpty) partnerId = partnerField[0] as int;
      }
      _userPartnerCache[userId] = partnerId;
      return partnerId;
    } catch (e, st) {
      ApiLogger.error('ChatterController._resolvePartnerForUser failed', e, st);
      return null;
    }
  }

  // -------------------- New chat: browse/search employees --------------------

  /// Lists employees for the "New Chat" picker. Empty query returns the
  /// first page so people can browse without typing anything, matching
  /// the Employee Directory's own behavior. Uses hr.employee.public —
  /// same model as the Directory feature, so it respects the same
  /// company-wide visibility (no group-membership restrictions).
  Future<List<Map<String, dynamic>>> fetchEmployeesForNewChat(String query) async {
    final client = _auth.odooClient;
    if (client == null) return [];
    try {
      final domain = query.trim().isEmpty
          ? [
        ['user_id', '!=', false],
      ]
          : [
        ['user_id', '!=', false],
        '|', '|',
        ['name', 'ilike', query],
        ['job_title', 'ilike', query],
        ['department_id.name', 'ilike', query],
      ];
      final result = await client
          .callKw({
        'model': 'hr.employee.public',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name', 'job_title', 'department_id', 'image_128', 'user_id'],
          'order': 'name asc',
          'limit': 60,
        },
      })
          .timeout(const Duration(seconds: 20));
      if (result is! List) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, st) {
      ApiLogger.error('ChatterController.fetchEmployeesForNewChat failed', e, st);
      return [];
    }
  }

  /// Starts (or reuses) a DM with an employee, resolving employee ->
  /// user -> partner along the way. Returns null with no side effects if
  /// the employee has no linked login (nothing to message).
  Future<int?> startChatWithEmployee(Map<String, dynamic> employeeRow) async {
    final name = employeeRow['name'];
    final userField = employeeRow['user_id'];
    final userId = (userField is List && userField.isNotEmpty) ? userField[0] as int : null;
    ApiLogger.info('ChatterController.startChatWithEmployee: name=$name userId=$userId');
    if (userId == null) {
      ApiLogger.error('ChatterController.startChatWithEmployee: no user_id on employee row for $name');
      return null;
    }

    final partnerId = await _resolvePartnerForUser(userId);
    ApiLogger.info('ChatterController.startChatWithEmployee: resolved partnerId=$partnerId for userId=$userId');
    if (partnerId == null) {
      ApiLogger.error('ChatterController.startChatWithEmployee: could not resolve partner for userId=$userId');
      return null;
    }

    final channelId = await startChatWith(partnerId);
    ApiLogger.info('ChatterController.startChatWithEmployee: channel_get returned channelId=$channelId');
    return channelId;
  }

  // -------------------- Inbox / Starred / History --------------------

  int? get myPartnerIdSync => _myPartnerId;

  Future<void> loadMailboxCounts() async {
    final client = _auth.odooClient;
    if (client == null) return;
    try {
      final myPartnerId = await _ensureMyPartnerId();

      final inbox = await client
          .callKw({
        'model': 'mail.message',
        'method': 'search_count',
        'args': [
          [
            ['needaction', '=', true],
          ],
        ],
        'kwargs': {},
      })
          .timeout(const Duration(seconds: 15));
      if (inbox is int) inboxCount.value = inbox;

      final starred = await client
          .callKw({
        'model': 'mail.message',
        'method': 'search_count',
        'args': [
          [
            ['starred', '=', true],
          ],
        ],
        'kwargs': {},
      })
          .timeout(const Duration(seconds: 15));
      if (starred is int) starredCount.value = starred;

      if (myPartnerId != null) {
        final history = await client
            .callKw({
          'model': 'mail.message',
          'method': 'search_count',
          'args': [
            [
              ['needaction', '=', false],
              ['partner_ids', 'in', [myPartnerId]],
            ],
          ],
          'kwargs': {},
        })
            .timeout(const Duration(seconds: 15));
        if (history is int) historyCount.value = history;
      }
    } catch (e, st) {
      ApiLogger.error('ChatterController.loadMailboxCounts failed', e, st);
    }
  }

  /// box: 'inbox' | 'starred' | 'history'
  Future<List<MailboxMessage>> fetchMailbox(String box) async {
    final client = _auth.odooClient;
    if (client == null) return [];
    try {
      List<dynamic> domain;
      switch (box) {
        case 'starred':
          domain = [
            ['starred', '=', true],
          ];
          break;
        case 'history':
          final myPartnerId = await _ensureMyPartnerId();
          domain = [
            ['needaction', '=', false],
            if (myPartnerId != null) ['partner_ids', 'in', [myPartnerId]],
          ];
          break;
        case 'inbox':
        default:
          domain = [
            ['needaction', '=', true],
          ];
      }

      final result = await client
          .callKw({
        'model': 'mail.message',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'body', 'author_id', 'date', 'record_name', 'model', 'res_id'],
          'order': 'date desc',
          'limit': 100,
        },
      })
          .timeout(const Duration(seconds: 20));

      if (result is! List) return [];
      return result.map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        final authorField = row['author_id'];
        final authorName = (authorField is List && authorField.length > 1) ? authorField[1] as String : 'Unknown';
        String body = row['body'] is String ? row['body'] as String : '';
        body = body.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        DateTime? date;
        final rawDate = row['date'];
        if (rawDate is String && rawDate.isNotEmpty) date = DateTime.tryParse(rawDate);

        return MailboxMessage(
          id: row['id'] as int,
          body: body,
          authorName: authorName,
          recordName: row['record_name'] is String ? row['record_name'] as String : null,
          model: row['model'] as String? ?? '',
          resId: row['res_id'] as int? ?? 0,
          date: date,
        );
      }).toList();
    } catch (e, st) {
      ApiLogger.error('ChatterController.fetchMailbox($box) failed', e, st);
      return [];
    }
  }

  // -------------------- Conversation list --------------------

  Future<void> loadConversations() async {
    final client = _auth.odooClient;
    if (client == null) return;
    isLoadingConversations.value = true;
    try {
      final fields = ['id', 'name', 'channel_type', 'image_128'];
      if (_unreadFieldSupported) fields.add('message_unread_counter');

      final result = await client
          .callKw({
        'model': 'discuss.channel',
        'method': 'search_read',
        'args': [
          [
            ['channel_type', 'in', ['chat', 'channel']],
          ],
        ],
        'kwargs': {'fields': fields, 'order': 'id desc', 'limit': 100},
      })
          .timeout(const Duration(seconds: 20));

      if (result is! List) {
        conversations.value = [];
        return;
      }

      conversations.value = result.map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        return ChatterConversation(
          id: row['id'] as int,
          name: row['name'] is String && (row['name'] as String).isNotEmpty
              ? row['name'] as String
              : 'Conversation',
          channelType: row['channel_type'] as String? ?? 'channel',
          unreadCount: (row['message_unread_counter'] is int) ? row['message_unread_counter'] as int : 0,
          imageBase64: row['image_128'] is String ? row['image_128'] as String : null,
        );
      }).toList();
    } catch (e, st) {
      final msg = e.toString();
      if (_unreadFieldSupported && msg.contains('message_unread_counter')) {
        _unreadFieldSupported = false;
        isLoadingConversations.value = false;
        return loadConversations();
      }
      ApiLogger.error('ChatterController.loadConversations failed', e, st);
    } finally {
      isLoadingConversations.value = false;
    }
  }

  /// Polls the conversation list quietly (no loading spinner) so unread
  /// badges update while the sheet is open, without the user doing anything.
  void startListPolling() {
    stopListPolling();
    loadMailboxCounts();
    _listPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _quietReloadConversations();
      loadMailboxCounts();
    });
  }

  void stopListPolling() {
    _listPollTimer?.cancel();
    _listPollTimer = null;
  }

  Future<void> _quietReloadConversations() async {
    final client = _auth.odooClient;
    if (client == null) return;
    try {
      final fields = ['id', 'name', 'channel_type', 'image_128'];
      if (_unreadFieldSupported) fields.add('message_unread_counter');
      final result = await client.callKw({
        'model': 'discuss.channel',
        'method': 'search_read',
        'args': [
          [
            ['channel_type', 'in', ['chat', 'channel']],
          ],
        ],
        'kwargs': {'fields': fields, 'order': 'id desc', 'limit': 100},
      }).timeout(const Duration(seconds: 15));
      if (result is! List) return;
      conversations.value = result.map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        return ChatterConversation(
          id: row['id'] as int,
          name: row['name'] is String && (row['name'] as String).isNotEmpty
              ? row['name'] as String
              : 'Conversation',
          channelType: row['channel_type'] as String? ?? 'channel',
          unreadCount: (row['message_unread_counter'] is int) ? row['message_unread_counter'] as int : 0,
          imageBase64: row['image_128'] is String ? row['image_128'] as String : null,
        );
      }).toList();
    } catch (_) {
      // Silent — this is a background refresh, not user-initiated.
    }
  }

  // -------------------- Start a new chat with anyone --------------------

  Future<List<Map<String, dynamic>>> searchPeople(String query) async {
    final client = _auth.odooClient;
    if (client == null || query.trim().length < 2) return [];
    try {
      final result = await client
          .callKw({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [
          [
            ['name', 'ilike', query],
          ],
        ],
        'kwargs': {'fields': ['id', 'name', 'email', 'image_128'], 'limit': 20},
      })
          .timeout(const Duration(seconds: 15));
      if (result is! List) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, st) {
      ApiLogger.error('ChatterController.searchPeople failed', e, st);
      return [];
    }
  }

  Future<int?> startChatWith(int partnerId) async {
    final client = _auth.odooClient;
    if (client == null) return null;
    try {
      final result = await client
          .callKw({
        'model': 'discuss.channel',
        'method': 'channel_get',
        'args': [],
        'kwargs': {
          'partners_to': [partnerId],
        },
      })
          .timeout(const Duration(seconds: 15));
      ApiLogger.info('ChatterController.startChatWith: channel_get raw result=$result');
      if (result is Map && result['id'] is int) {
        await loadConversations();
        return result['id'] as int;
      }
      ApiLogger.error('ChatterController.startChatWith: unexpected result shape=$result');
      return null;
    } catch (e, st) {
      ApiLogger.error('ChatterController.startChatWith failed for partnerId=$partnerId', e, st);
      return null;
    }
  }

  // -------------------- Thread --------------------

  Future<void> openThread(int channelId) async {
    final client = _auth.odooClient;
    if (client == null) return;
    _openChannelId = channelId;
    _lastMessageId = 0;
    isLoadingThread.value = true;
    threadMessages.clear();
    try {
      final result = await client
          .callKw({
        'model': 'mail.message',
        'method': 'search_read',
        'args': [
          [
            ['model', '=', 'discuss.channel'],
            ['res_id', '=', channelId],
            ['message_type', '!=', 'notification'],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'body', 'author_id', 'date'],
          'order': 'id asc',
          'limit': 200,
        },
      })
          .timeout(const Duration(seconds: 20));

      if (result is List) {
        final myPartnerId = await _ensureMyPartnerId();
        threadMessages.value = result.map((raw) => _mapMessage(Map<String, dynamic>.from(raw as Map), myPartnerId)).toList();
        if (threadMessages.isNotEmpty) _lastMessageId = threadMessages.last.id;
      }
      await _markSeen(channelId);
      _startThreadPolling(channelId);
    } catch (e, st) {
      ApiLogger.error('ChatterController.openThread failed', e, st);
    } finally {
      isLoadingThread.value = false;
    }
  }

  ChatterMessage _mapMessage(Map<String, dynamic> row, int? myPartnerId) {
    final authorField = row['author_id'];
    final authorId = (authorField is List && authorField.isNotEmpty) ? authorField[0] as int : null;
    final authorName = (authorField is List && authorField.length > 1) ? authorField[1] as String : 'Unknown';
    String body = row['body'] is String ? row['body'] as String : '';
    body = body.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    DateTime? date;
    final rawDate = row['date'];
    if (rawDate is String && rawDate.isNotEmpty) date = DateTime.tryParse(rawDate);

    return ChatterMessage(
      id: row['id'] as int,
      body: body,
      authorName: authorName,
      authorId: authorId,
      date: date,
      isMine: myPartnerId != null && authorId == myPartnerId,
    );
  }

  void _startThreadPolling(int channelId) {
    _threadPollTimer?.cancel();
    _threadPollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollNewMessages(channelId));
  }

  Future<void> _pollNewMessages(int channelId) async {
    if (_openChannelId != channelId) return;
    final client = _auth.odooClient;
    if (client == null) return;
    try {
      final result = await client.callKw({
        'model': 'mail.message',
        'method': 'search_read',
        'args': [
          [
            ['model', '=', 'discuss.channel'],
            ['res_id', '=', channelId],
            ['message_type', '!=', 'notification'],
            ['id', '>', _lastMessageId],
          ],
        ],
        'kwargs': {'fields': ['id', 'body', 'author_id', 'date'], 'order': 'id asc'},
      }).timeout(const Duration(seconds: 15));

      if (result is List && result.isNotEmpty) {
        final myPartnerId = await _ensureMyPartnerId();
        final newOnes = result.map((raw) => _mapMessage(Map<String, dynamic>.from(raw as Map), myPartnerId)).toList();
        threadMessages.addAll(newOnes);
        _lastMessageId = newOnes.last.id;
        await _markSeen(channelId);
      }
    } catch (_) {
      // Silent — background poll.
    }
  }

  Future<void> _markSeen(int channelId) async {
    final client = _auth.odooClient;
    if (client == null) return;
    try {
      await client.callKw({
        'model': 'discuss.channel',
        'method': 'channel_seen',
        'args': [
          [channelId]
        ],
        'kwargs': {},
      }).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Non-critical.
    }
  }

  void closeThread() {
    _threadPollTimer?.cancel();
    _threadPollTimer = null;
    _openChannelId = 0;
  }

  Future<bool> sendMessage(int channelId, String text) async {
    final client = _auth.odooClient;
    if (client == null || text.trim().isEmpty) return false;
    isSending.value = true;
    try {
      await client
          .callKw({
        'model': 'discuss.channel',
        'method': 'message_post',
        'args': [channelId],
        'kwargs': {
          'body': text.trim(),
          'message_type': 'comment',
          'subtype_xmlid': 'mail.mt_comment',
        },
      })
          .timeout(const Duration(seconds: 20));
      await _pollNewMessages(channelId);
      return true;
    } catch (e, st) {
      ApiLogger.error('ChatterController.sendMessage failed', e, st);
      return false;
    } finally {
      isSending.value = false;
    }
  }
}