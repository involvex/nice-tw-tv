import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/notifications/data/notification_payload.dart';

void main() {
  group('parseWatchNotificationPayload', () {
    test('parses watch:login:userId', () {
      final target = parseWatchNotificationPayload('watch:shroud:12345');
      expect(target, isNotNull);
      expect(target!.login, 'shroud');
      expect(target.userId, '12345');
    });

    test('allows colons in userId segment', () {
      final target = parseWatchNotificationPayload(
        'watch:login:id:with:colons',
      );
      expect(target, isNotNull);
      expect(target!.login, 'login');
      expect(target.userId, 'id:with:colons');
    });

    test('returns null for null or empty', () {
      expect(parseWatchNotificationPayload(null), isNull);
      expect(parseWatchNotificationPayload(''), isNull);
    });

    test('returns null for wrong scheme or incomplete', () {
      expect(parseWatchNotificationPayload('open:shroud:1'), isNull);
      expect(parseWatchNotificationPayload('watch:shroud'), isNull);
      expect(parseWatchNotificationPayload('watch::123'), isNull);
      expect(parseWatchNotificationPayload('watch:shroud:'), isNull);
    });
  });
}
