import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';

void main() {
  group('maskLinksInText', () {
    test('masks a single URL', () {
      expect(
        maskLinksInText('check https://example.com/stream spoiler'),
        'check [link] spoiler',
      );
    });

    test('masks multiple URLs', () {
      expect(
        maskLinksInText('see https://a.com and https://b.com'),
        'see [link] and [link]',
      );
    });

    test('leaves text without URLs unchanged', () {
      expect(maskLinksInText('just a normal message'), 'just a normal message');
    });

    test('handles http scheme', () {
      expect(maskLinksInText('http://twitch.tv/x'), '[link]');
    });

    test('empty string returns empty', () {
      expect(maskLinksInText(''), '');
    });
  });

  group('formatChatTimestamp', () {
    test('zero-pads single digit hour and minute', () {
      expect(formatChatTimestamp(DateTime(2024, 1, 1, 9, 5)), '09:05');
    });

    test('formats two-digit hour and minute', () {
      expect(formatChatTimestamp(DateTime(2024, 1, 1, 14, 32)), '14:32');
    });
  });
}
