import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../auth/controllers/auth_controller.dart';

class MessagingController extends GetxController {
  final AuthController _authController = Get.find<AuthController>();

  final channels = <Map<String, dynamic>>[].obs;
  final directMessages = <Map<String, dynamic>>[].obs;
  final allConversations = <Map<String, dynamic>>[].obs;

  final isLoadingChannels = false.obs;
  final isLoadingChats = false.obs;
  final isRefreshing = false.obs;

  final currentConversation = Rxn<Map<String, dynamic>>();
  final conversationMessages = <Map<String, dynamic>>[].obs;
  final isLoadingMessages = false.obs;

  final totalUnreadCount = 0.obs;

  Timer? _messagePollingTimer;
  int _lastFetchedMessageId = 0;
  int _currentChannelId = 0;

  @override
  void onInit() {
    super.onInit();
    loadAllConversations();
  }

  void startMessagePolling(int channelId) {
    stopMessagePolling();
    _messagePollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isSessionValid() && _currentChannelId == channelId) {
        await fetchNewMessages(channelId);
      } else {
        stopMessagePolling();
      }
    });
  }

  void stopMessagePolling() {
    _messagePollingTimer?.cancel();
    _messagePollingTimer = null;
  }

  Future<void> loadAllConversations() async {
    if (!_isSessionValid()) return;

    try {
      isRefreshing.value = true;
      await Future.wait([loadChannels(), loadDirectMessages()]);

      final all = [...channels, ...directMessages];
      all.sort((a, b) {
        final dateA = a['last_message_date'] ?? '';
        final dateB = b['last_message_date'] ?? '';
        return dateB.toString().compareTo(dateA.toString());
      });

      allConversations.value = all;
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<void> loadChannels() async {
    if (!_isSessionValid()) return;

    try {
      isLoadingChannels.value = true;
      final client = _authController.odooClient;
      if (client == null) throw Exception('Not logged in');

      final result = await client.callKw({
        'model': 'discuss.channel',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['channel_type', '=', 'channel'],
          ],
          'fields': [
            'id',
            'name',
            'description',
            'channel_type',
            'channel_partner_ids',
            'uuid',
          ],
          'order': 'name asc',
        },
      });

      if (result is List) {
        channels.value = result.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error loading channels: $e');
    } finally {
      isLoadingChannels.value = false;
    }
  }

  Future<void> loadDirectMessages() async {
    if (!_isSessionValid()) return;

    try {
      isLoadingChats.value = true;
      final client = _authController.odooClient;
      if (client == null) throw Exception('Not logged in');

      final result = await client.callKw({
        'model': 'discuss.channel',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['channel_type', '=', 'chat'],
          ],
          'fields': [
            'id',
            'name',
            'channel_type',
            'channel_partner_ids',
            'uuid',
          ],
          'order': 'name asc',
        },
      });

      if (result is List) {
        directMessages.value = result.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error loading direct messages: $e');
    } finally {
      isLoadingChats.value = false;
    }
  }

  Future<void> fetchNewMessages(int channelId) async {
    if (!_isSessionValid()) return;

    try {
      final client = _authController.odooClient;
      if (client == null) return;

      final result = await client.callKw({
        'model': 'mail.message',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['model', '=', 'discuss.channel'],
            ['res_id', '=', channelId],
            ['message_type', '!=', 'notification'],
            if (_lastFetchedMessageId > 0) ['id', '>', _lastFetchedMessageId],
          ],
          'fields': [
            'id',
            'body',
            'author_id',
            'date',
            'message_type',
            'attachment_ids',
          ],
          'order': 'id asc',
        },
      });

      if (result is List && result.isNotEmpty) {
        final newMessages = result.cast<Map<String, dynamic>>();
        conversationMessages.addAll(newMessages);
        _lastFetchedMessageId = newMessages.last['id'] as int;
      }
    } catch (e) {
      debugPrint('Error fetching new messages: $e');
    }
  }

  Future<void> loadConversationMessages(int channelId, {bool showLoading = true}) async {
    if (!_isSessionValid()) return;

    try {
      if (showLoading) isLoadingMessages.value = true;

      _currentChannelId = channelId;
      conversationMessages.clear();
      _lastFetchedMessageId = 0;

      final client = _authController.odooClient;
      if (client == null) throw Exception('Not logged in');

      final result = await client.callKw({
        'model': 'mail.message',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['model', '=', 'discuss.channel'],
            ['res_id', '=', channelId],
            ['message_type', '!=', 'notification'],
          ],
          'fields': ['id', 'body', 'author_id', 'date', 'message_type'],
          'order': 'id asc',
          'limit': 100,
        },
      });

      if (result is List) {
        conversationMessages.value = result.cast<Map<String, dynamic>>();
        if (conversationMessages.isNotEmpty) {
          _lastFetchedMessageId = conversationMessages.last['id'] as int;
        }
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      if (showLoading) isLoadingMessages.value = false;
    }
  }

  Future<bool> sendMessage(int channelId, String message) async {
    if (!_isSessionValid() || message.trim().isEmpty) return false;

    try {
      final client = _authController.odooClient;
      if (client == null) throw Exception('Not logged in');

      final result = await client.callKw({
        'model': 'discuss.channel',
        'method': 'message_post',
        'args': [channelId],
        'kwargs': {
          'body': message,
          'message_type': 'comment',
          'subtype_xmlid': 'mail.mt_comment',
        },
      });

      if (result != null) {
        await loadConversationMessages(channelId, showLoading: false);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  Future<int?> createChannel(String name, String description) async {
    if (!_isSessionValid()) return null;

    try {
      final client = _authController.odooClient;
      if (client == null) throw Exception('Not logged in');

      final result = await client.callKw({
        'model': 'discuss.channel',
        'method': 'create',
        'args': [
          {
            'name': name,
            'description': description,
            'channel_type': 'channel',
          }
        ],
        'kwargs': {},
      });

      if (result is int) {
        await loadChannels();
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating channel: $e');
      return null;
    }
  }

  Future<int?> createDirectMessage(int partnerId) async {
    if (!_isSessionValid()) return null;

    try {
      final client = _authController.odooClient;
      if (client == null) throw Exception('Not logged in');

      final result = await client.callKw({
        'model': 'discuss.channel',
        'method': 'channel_get',
        'args': [],
        'kwargs': {
          'partners_to': [partnerId],
        },
      });

      // This Odoo version's channel_get returns a "store" bundle keyed by
      // model name (e.g. {'discuss.channel': [{...}], 'discuss.channel.member': [...]})
      // rather than the channel record directly — the channel's own id is
      // nested inside the first 'discuss.channel' list entry.
      if (result is Map) {
        final channels = result['discuss.channel'];
        if (channels is List && channels.isNotEmpty) {
          final channel = channels.first;
          if (channel is Map && channel['id'] is int) {
            await loadDirectMessages();
            return channel['id'] as int;
          }
        }
      }
      debugPrint('Unexpected channel_get result shape: $result');
      return null;
    } catch (e) {
      debugPrint('Error creating direct message: $e');
      return null;
    }
  }

  Future<void> markAsRead(int channelId) async {
    if (!_isSessionValid()) return;

    try {
      final client = _authController.odooClient;
      if (client == null) throw Exception('Not logged in');

      await client.callKw({
        'model': 'discuss.channel',
        'method': 'channel_seen',
        'args': [
          [channelId]
        ],
        'kwargs': {},
      });

      await loadAllConversations();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchPartners(String query) async {
    if (!_isSessionValid() || query.trim().isEmpty) return [];

    try {
      final client = _authController.odooClient;
      if (client == null) throw Exception('Not logged in');

      final result = await client.callKw({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['name', 'ilike', query],
          ],
          'fields': ['id', 'name', 'email', 'image_128'],
          'limit': 20,
        },
      });

      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching partners: $e');
      return [];
    }
  }

  bool _isSessionValid() {
    return _authController.isLoggedIn.value && _authController.odooClient != null;
  }

  @override
  void onClose() {
    stopMessagePolling();
    channels.clear();
    directMessages.clear();
    allConversations.clear();
    conversationMessages.clear();
    super.onClose();
  }
}
