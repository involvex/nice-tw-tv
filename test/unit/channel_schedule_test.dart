import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/profile/data/channel_schedule.dart';

void main() {
  group('ChannelSchedule.fromJson', () {
    test('parses segments', () {
      final schedule = ChannelSchedule.fromJson({
        'data': [
          {
            'segments': [
              {
                'id': 'seg1',
                'start_time': '2026-08-30T18:14:16Z',
                'end_time': '2026-08-30T18:34:16Z',
                'title': 'Playing Fortnite',
                'category': {'id': '33214', 'name': 'Fortnite'},
                'is_recurring': true,
              },
              {
                'id': 'seg2',
                'start_time': '2026-09-01T18:00:00Z',
                'end_time': '2026-09-01T19:00:00Z',
                'title': '',
                'category': null,
                'is_recurring': false,
              },
            ],
          },
        ],
      });
      expect(schedule.segments.length, 2);
      final first = schedule.segments.first;
      expect(first.id, 'seg1');
      expect(first.title, 'Playing Fortnite');
      expect(first.categoryId, '33214');
      expect(first.categoryName, 'Fortnite');
      expect(first.isRecurring, isTrue);
      expect(first.startTime.isUtc, isTrue);
    });

    test('handles empty payload', () {
      final schedule = ChannelSchedule.fromJson(const {'data': []});
      expect(schedule.segments, isEmpty);
    });
  });

  group('formatScheduleTime', () {
    test('formats a time with day, month, and clock', () {
      final formatted = formatScheduleTime(DateTime(2026, 8, 30, 18, 14));
      expect(formatted, contains('Sun'));
      expect(formatted, contains('Aug'));
      expect(formatted, contains('30'));
      expect(formatted, contains('6:14 PM'));
    });

    test('formats midnight as 12:00 AM', () {
      final formatted = formatScheduleTime(DateTime(2026, 8, 30, 0, 0));
      expect(formatted, contains('12:00 AM'));
    });
  });
}
