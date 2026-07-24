import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/notifications/data/notifications_inbox.dart';

/// Local OS notifications for live alerts (works without Firebase).
/// Remote FCM delivery is handled by the token-proxy worker when configured.
class LocalPushService {
  LocalPushService();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'live_alerts',
          'Live alerts',
          description: 'Followed channels going live',
          importance: Importance.high,
        ),
      );
      _ready = true;
    } on Object {
      // Missing plugin binding in tests / unsupported hosts.
      _ready = false;
    }
  }

  Future<void> showWentLive(LiveNotificationItem item) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: item.userId.hashCode,
        title: '${item.userName} is live',
        body: item.title.isEmpty ? 'Started streaming' : item.title,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'live_alerts',
            'Live alerts',
            channelDescription: 'Followed channels going live',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.social,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'watch:${item.userLogin}:${item.userId}',
      );
    } on Object {
      // Ignore notification delivery failures.
    }
  }
}

final localPushServiceProvider = Provider<LocalPushService>((ref) {
  return LocalPushService();
});
