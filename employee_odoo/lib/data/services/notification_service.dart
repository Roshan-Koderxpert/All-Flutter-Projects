import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../modules/notifications/controllers/notification_controller.dart';
import '../models/notification_model.dart';

// Must be a top-level function.
// Runs in a separate isolate when the app is killed/backgrounded.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Keep this minimal.
}

class NotificationService extends GetxService {
  final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  Future<NotificationService> init() async {
    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialization settings for Android and iOS
    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize local notifications
    await _local.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create Android notification channel
    const AndroidNotificationChannel channel =
    AndroidNotificationChannel(
      'default_channel',
      'General',
      description: 'General application notifications',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Firebase Messaging is currently disabled
    // until Firebase iOS configuration is completed.
    //
    // await FirebaseMessaging.instance.requestPermission(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    // );
    //
    // FirebaseMessaging.onMessage.listen(_showLocal);
    //
    // FirebaseMessaging.onMessageOpenedApp.listen(
    //   (message) => _route(message.data),
    // );
    //
    // FirebaseMessaging.onBackgroundMessage(
    //   firebaseBackgroundHandler,
    // );

    return this;
  }

  // TODO: Enable when Firebase setup is completed.
  Future<String?> getToken() async {
    return null;
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final String title = message.notification?.title ?? '';
    final String body = message.notification?.body ?? '';

    _saveToHistory(
      title,
      body,
      message.data,
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(
      android: AndroidNotificationDetails(
        'default_channel',
        'General',
        channelDescription: 'General application notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  void _onTap(NotificationResponse response) {
    final String? payload = response.payload;

    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final dynamic decodedData = jsonDecode(payload);

      if (decodedData is Map) {
        final Map<String, dynamic> data =
        Map<String, dynamic>.from(decodedData);

        _route(data);
      }
    } catch (e) {
      // Ignore invalid notification payload.
    }
  }

  void _route(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'leave_status':
        final int? recordId = int.tryParse(
          data['record_id']?.toString() ?? '',
        );

        if (recordId != null) {
          Get.toNamed(
            AppRoutes.allocationDetail,
            arguments: recordId,
          );
        }
        break;

      case 'chat_message':
        Get.toNamed(
          '/messaging/conversation',
          arguments: data['channel_id'],
        );
        break;

      case 'attendance_reminder':
        Get.toNamed(AppRoutes.home);
        break;

      default:
        Get.toNamed(AppRoutes.home);
        break;
    }
  }

  void _saveToHistory(
      String title,
      String body,
      Map<String, dynamic> data,
      ) {
    if (!Get.isRegistered<NotificationController>()) {
      return;
    }

    Get.find<NotificationController>().addNotification(
      NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        type: data['type']?.toString() ?? '',
        recordId: int.tryParse(
          data['record_id']?.toString() ?? '',
        ),
        timestamp: DateTime.now(),
      ),
    );
  }
}