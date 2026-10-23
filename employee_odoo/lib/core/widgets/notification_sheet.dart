import 'package:employee_odoo/core/widgets/task_notification_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../data/models/notification_model.dart';
import '../../modules/notifications/controllers/notification_controller.dart';
import 'leave_notification_sheet.dart';

void showNotificationSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const NotificationSheet(),
  );
}

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: controller.markAllAsRead, child: const Text('Mark all read')),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.notifications.isEmpty) {
                return const Center(child: Text('No notifications yet'));
              }
              return ListView.separated(
                controller: scrollController,
                itemCount: controller.notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final n = controller.notifications[index];
                  return ListTile(
                    tileColor: n.isRead ? null : Colors.blue.withOpacity(0.05),
                    leading: CircleAvatar(
                      backgroundColor: _colorForType(n.type),
                      child: Icon(_iconForType(n.type), color: Colors.white, size: 18),
                    ),
                    title: Text(n.title,
                        style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(_timeAgo(n.timestamp), style: const TextStyle(fontSize: 11)),
                    onTap: () {
                      controller.markAsRead(n.id);
                      Navigator.pop(context);
                      _routeToRecord(context, n);
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'leave_status':
        return Colors.orange;
      case 'chat_message':
        return Colors.blue;
      case 'task_assigned':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'leave_status':
        return Icons.event_available;
      case 'chat_message':
        return Icons.chat_bubble;
      case 'task_assigned':
        return Icons.task_alt;
      default:
        return Icons.notifications;
    }
  }

  void _routeToRecord(BuildContext context, NotificationModel n) {
    switch (n.type) {
      case 'leave_status':
        if (n.recordId != null) {
          showLeaveNotificationSheet(context, n.recordId!);
        }
        break;
      case 'task_assigned':
        if (n.recordId != null) {
          showTaskNotificationSheet(context, n.recordId!);
        }
        break;
      case 'chat_message':
        Get.toNamed('/messaging/conversation', arguments: n.recordId);
        break;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}