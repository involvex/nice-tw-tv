import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/settings/data/quiet_hours.dart';

void main() {
  group('isInQuietHours', () {
    DateTime at(int hour, int minute) => DateTime(2026, 8, 20, hour, minute);

    test('inside same-day window', () {
      expect(isInQuietHours(at(23, 0), 22 * 60, 7 * 60), isTrue);
      expect(isInQuietHours(at(6, 59), 22 * 60, 7 * 60), isTrue);
    });

    test('outside same-day window', () {
      expect(isInQuietHours(at(12, 0), 22 * 60, 7 * 60), isFalse);
    });

    test('wrap-around window crosses midnight', () {
      expect(isInQuietHours(at(1, 0), 22 * 60, 7 * 60), isTrue);
      expect(isInQuietHours(at(23, 30), 22 * 60, 7 * 60), isTrue);
    });

    test('non-wrapping window', () {
      expect(isInQuietHours(at(9, 0), 8 * 60, 10 * 60), isTrue);
      expect(isInQuietHours(at(7, 0), 8 * 60, 10 * 60), isFalse);
    });

    test('equal start/end means no quiet hours', () {
      expect(isInQuietHours(at(9, 0), 9 * 60, 9 * 60), isFalse);
    });
  });
}
