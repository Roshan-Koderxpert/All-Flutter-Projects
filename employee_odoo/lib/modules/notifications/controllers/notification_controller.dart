import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../data/models/notification_model.dart';

class NotificationController extends GetxController {
  final _box = GetStorage();
  static const _key = 'notification_history';

  final notifications = <NotificationModel>[].obs;
  final unreadCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final raw = _box.read<List>(_key) ?? [];
    notifications.value = raw
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _updateUnread();
  }

  void _save() => _box.write(_key, notifications.map((n) => n.toJson()).toList());

  void _updateUnread() =>
      unreadCount.value = notifications.where((n) => !n.isRead).length;

  void addNotification(NotificationModel n) {
    notifications.insert(0, n);
    if (notifications.length > 100) {
      notifications.removeRange(100, notifications.length);
    }
    _save();
    _updateUnread();
  }

  void markAsRead(String id) {
    final i = notifications.indexWhere((n) => n.id == id);
    if (i != -1 && !notifications[i].isRead) {
      notifications[i].isRead = true;
      notifications.refresh();
      _save();
      _updateUnread();
    }
  }

  void markAllAsRead() {
    for (var n in notifications) {
      n.isRead = true;
    }
    notifications.refresh();
    _save();
    _updateUnread();
  }
}