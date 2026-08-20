import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';

void main() {
  group('RoomState', () {
    test('parses ROOMSTATE tags', () {
      final state = RoomState.fromIrcTags({
        'slow': '30',
        'followers-only': '5',
        'subs-only': '1',
        'emote-only': '1',
      });
      expect(state.slow, isTrue);
      expect(state.followersOnly, isTrue);
      expect(state.followerOnlyMinutes, 5);
      expect(state.subscribersOnly, isTrue);
      expect(state.emotesOnly, isTrue);
    });

    test('parses disabled flags', () {
      final state = RoomState.fromIrcTags({
        'slow': '0',
        'followers-only': '-1',
        'subs-only': '0',
        'emote-only': '0',
      });
      expect(state.slow, isFalse);
      expect(state.followersOnly, isFalse);
      expect(state.followerOnlyMinutes, 0);
      expect(state.subscribersOnly, isFalse);
      expect(state.emotesOnly, isFalse);
    });

    test('handles empty tags', () {
      final state = RoomState.fromIrcTags({});
      expect(state.slow, isFalse);
      expect(state.followersOnly, isFalse);
      expect(state.subscribersOnly, isFalse);
      expect(state.emotesOnly, isFalse);
    });
  });

  group('ChatMessage serialization', () {
    test('round-trips a chat message', () {
      final message = ChatMessage(
        id: 'm1',
        channel: 'chan',
        login: 'viewer',
        displayName: 'Viewer',
        message: 'Hello world',
        color: '#FF0000',
        isAction: false,
        timestamp: DateTime.utc(2026, 8, 20),
        badges: const [ChatBadgeRef(setId: 'vip', version: '1')],
        bits: 5,
        replyParent: const ChatReplyParent(
          messageId: 'p1',
          userLogin: 'host',
          displayName: 'Host',
          body: 'orig',
        ),
      );
      final restored = ChatMessage.fromJson(message.toJson());
      expect(restored.id, 'm1');
      expect(restored.channel, 'chan');
      expect(restored.login, 'viewer');
      expect(restored.displayName, 'Viewer');
      expect(restored.message, 'Hello world');
      expect(restored.color, '#FF0000');
      expect(restored.timestamp, DateTime.utc(2026, 8, 20));
      expect(restored.badges.single.setId, 'vip');
      expect(restored.bits, 5);
      expect(restored.replyParent?.messageId, 'p1');
      expect(restored.system, isFalse);
    });

    test('round-trips a system message', () {
      final message = ChatMessage.system('Hello');
      final restored = ChatMessage.fromJson(message.toJson());
      expect(restored.system, isTrue);
      expect(restored.message, 'Hello');
    });
  });

  group('filterBlocked', () {
    test('removes messages from blocked users', () {
      final messages = [
        ChatMessage(
          id: '1',
          channel: 'c',
          login: 'blocked',
          displayName: 'Blocked',
          message: 'x',
          color: null,
          isAction: false,
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: '2',
          channel: 'c',
          login: 'ok',
          displayName: 'Ok',
          message: 'y',
          color: null,
          isAction: false,
          timestamp: DateTime.now(),
        ),
      ];
      final filtered = filterBlocked(messages, {'blocked'});
      expect(filtered.single.id, '2');
    });

    test('keeps system messages', () {
      final messages = [
        ChatMessage.system('Joined #chan'),
        ChatMessage(
          id: '2',
          channel: 'c',
          login: 'blocked',
          displayName: 'Blocked',
          message: 'x',
          color: null,
          isAction: false,
          timestamp: DateTime.now(),
        ),
      ];
      final filtered = filterBlocked(messages, {'blocked'});
      expect(filtered.single.system, isTrue);
    });
  });
}
