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
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
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
  }

  Future<void> showWentLive(LiveNotificationItem item) async {
    await init();
    await _plugin.show(
      item.userId.hashCode,
      '${item.userName} is live',
      item.title.isEmpty ? 'Started streaming' : item.title,
      const NotificationDetails(
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
  }
}

final localPushServiceProvider = Provider<LocalPushService>((ref) {
  return LocalPushService();
});
