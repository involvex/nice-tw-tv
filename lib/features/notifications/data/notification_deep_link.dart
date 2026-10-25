import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/notifications/data/notification_payload.dart';

/// Holds a pending watch deep-link from a notification tap (including cold start).
class NotificationDeepLinkController
    extends Notifier<WatchNotificationTarget?> {
  @override
  WatchNotificationTarget? build() => null;

  void offer(WatchNotificationTarget? target) {
    if (target == null) return;
    state = target;
  }

  void offerPayload(String? payload) {
    offer(parseWatchNotificationPayload(payload));
  }

  void clear() {
    state = null;
  }
}

final notificationDeepLinkProvider =
    NotifierProvider<NotificationDeepLinkController, WatchNotificationTarget?>(
      NotificationDeepLinkController.new,
    );
