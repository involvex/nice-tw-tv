/// Parsed deep-link from a live-alert notification payload.
typedef WatchNotificationTarget = ({String login, String userId});

/// Parses `watch:login:userId` payloads written by [LocalPushService].
///
/// Returns `null` when the payload is missing, malformed, or incomplete.
WatchNotificationTarget? parseWatchNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  final parts = payload.split(':');
  if (parts.length < 3) return null;
  if (parts[0] != 'watch') return null;
  final login = parts[1].trim();
  final userId = parts.sublist(2).join(':').trim();
  if (login.isEmpty || userId.isEmpty) return null;
  return (login: login, userId: userId);
}
