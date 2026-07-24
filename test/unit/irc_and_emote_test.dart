import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';
import 'package:nice_tv/features/emotes/data/emote.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/notifications/data/notifications_inbox.dart';

void main() {
  group('IrcMessageParser', () {
    test('parses tagged PRIVMSG', () {
      const raw =
          '@badge-info=;badges=;color=#1E90FF;display-name=CoolViewer;emotes=;'
          'id=abc-123;mod=0;room-id=123;subscriber=0;tmi-sent-ts=1507246572675;'
          'turbo=0;user-id=1337;user-type= '
          ':coolviewer!coolviewer@coolviewer.tmi.twitch.tv PRIVMSG #ninja '
          ':Hello world Kappa';

      final message = const IrcMessageParser().toChatMessage(raw);
      expect(message, isNotNull);
      expect(message!.displayName, 'CoolViewer');
      expect(message.login, 'coolviewer');
      expect(message.channel, 'ninja');
      expect(message.message, 'Hello world Kappa');
      expect(message.color, '#1E90FF');
      expect(message.id, 'abc-123');
    });

    test('parses badges from tags', () {
      const raw =
          '@badges=broadcaster/1,subscriber/12,vip/1;color=#FF0000;'
          'display-name=Host;id=b-1 '
          ':host!host@host.tmi.twitch.tv PRIVMSG #host :hi';
      final message = const IrcMessageParser().toChatMessage(raw);
      expect(message, isNotNull);
      expect(message!.badges.map((b) => '${b.setId}/${b.version}'), [
        'broadcaster/1',
        'subscriber/12',
        'vip/1',
      ]);
    });

    test('parses reply and bits tags', () {
      const raw =
          '@badges=;bits=100;color=#FF0000;display-name=Cheerer;'
          'id=cheer-1;reply-parent-msg-id=parent-9;'
          'reply-parent-display-name=Host;reply-parent-user-login=host;'
          'reply-parent-msg-body=hello\\sthere '
          ':cheerer!c@c.tmi.twitch.tv PRIVMSG #host :Cheer100 nice';
      final message = const IrcMessageParser().toChatMessage(raw);
      expect(message, isNotNull);
      expect(message!.bits, 100);
      expect(message.isCheer, isTrue);
      expect(message.replyParent?.messageId, 'parent-9');
      expect(message.replyParent?.displayName, 'Host');
      expect(message.replyParent?.body, 'hello there');
    });

    test('parses ACTION messages', () {
      const raw =
          '@display-name=Actor;color=;id=act-1 '
          ':actor!actor@actor.tmi.twitch.tv PRIVMSG #chan '
          ':\u0001ACTION waves\u0001';
      final message = const IrcMessageParser().toChatMessage(raw);
      expect(message, isNotNull);
      expect(message!.isAction, isTrue);
      expect(message.message, 'waves');
    });

    test('parseLine extracts tags and trailing param', () {
      final parsed = IrcMessageParser.parseLine(
        '@a=1;b=two :nick!u@h PRIVMSG #c :hello there',
      );
      expect(parsed.tags['a'], '1');
      expect(parsed.tags['b'], 'two');
      expect(parsed.command, 'PRIVMSG');
      expect(parsed.params, ['#c', 'hello there']);
    });
  });

  group('tokenizeMessage', () {
    test('splits text and emotes', () {
      final catalog = EmoteCatalog(
        byName: {
          'Kappa': const Emote(
            id: '1',
            name: 'Kappa',
            url: 'https://example.com/kappa.png',
            provider: EmoteProvider.twitch,
          ),
          'Pog': const Emote(
            id: '2',
            name: 'Pog',
            url: 'https://example.com/pog.png',
            provider: EmoteProvider.bttv,
          ),
        },
      );

      final segments = tokenizeMessage('Hi Kappa there Pog end', catalog);
      expect(segments.length, 5);
      expect(segments[0], isA<TextSegment>());
      expect((segments[0] as TextSegment).value, 'Hi ');
      expect(segments[1], isA<EmoteSegment>());
      expect((segments[1] as EmoteSegment).emote.name, 'Kappa');
      expect(segments[2], isA<TextSegment>());
      expect((segments[2] as TextSegment).value, ' there ');
      expect(segments[3], isA<EmoteSegment>());
      expect((segments[3] as EmoteSegment).emote.name, 'Pog');
      expect(segments[4], isA<TextSegment>());
      expect((segments[4] as TextSegment).value, ' end');
    });

    test('suggest filters by prefix', () {
      final catalog = EmoteCatalog(
        byName: {
          'Kappa': const Emote(
            id: '1',
            name: 'Kappa',
            url: 'u',
            provider: EmoteProvider.twitch,
          ),
          'Keepo': const Emote(
            id: '2',
            name: 'Keepo',
            url: 'u',
            provider: EmoteProvider.twitch,
          ),
          'Pog': const Emote(
            id: '3',
            name: 'Pog',
            url: 'u',
            provider: EmoteProvider.bttv,
          ),
        },
      );
      final hits = catalog.suggest('ke');
      expect(hits.map((e) => e.name), ['Keepo']);
    });

    test('filter by provider and query', () {
      final catalog = EmoteCatalog(
        byName: {
          'Kappa': const Emote(
            id: '1',
            name: 'Kappa',
            url: 'u',
            provider: EmoteProvider.twitch,
          ),
          'Pog': const Emote(
            id: '2',
            name: 'Pog',
            url: 'u',
            provider: EmoteProvider.bttv,
          ),
        },
      );
      expect(catalog.filter(provider: EmoteProvider.bttv).map((e) => e.name), [
        'Pog',
      ]);
      expect(catalog.filter(query: 'ka').map((e) => e.name), ['Kappa']);
    });
  });

  group('diffWentLive', () {
    TwitchStream stream({
      required String userId,
      String login = 'chan',
      DateTime? started,
    }) {
      return TwitchStream(
        id: 's-$userId',
        userId: userId,
        userLogin: login,
        userName: login,
        gameName: 'Game',
        title: 'Live now',
        viewerCount: 10,
        thumbnailUrl: '',
        startedAt: started ?? DateTime.utc(2026, 1, 1),
        isMature: false,
        language: 'en',
      );
    }

    test('emits items only for newly live channels', () {
      final fresh = diffWentLive(
        previousLiveUserIds: {'a'},
        currentLive: [
          stream(userId: 'a', login: 'alpha'),
          stream(userId: 'b', login: 'beta'),
        ],
        knownNotificationIds: {},
      );
      expect(fresh.length, 1);
      expect(fresh.first.userId, 'b');
      expect(fresh.first.userLogin, 'beta');
      expect(fresh.first.read, isFalse);
    });

    test('skips known notification ids', () {
      final known = LiveNotificationItem.fromStream(
        stream(userId: 'b', login: 'beta'),
      );
      final fresh = diffWentLive(
        previousLiveUserIds: {},
        currentLive: [stream(userId: 'b', login: 'beta')],
        knownNotificationIds: {known.id},
      );
      expect(fresh, isEmpty);
    });

    test(
      'first snapshot with empty previous still reports when not seeded',
      () {
        // Controller seeds first poll; pure diff still reports all as new.
        final fresh = diffWentLive(
          previousLiveUserIds: {},
          currentLive: [stream(userId: 'c')],
          knownNotificationIds: {},
        );
        expect(fresh.length, 1);
      },
    );
  });

  group('ChatBadgeRef', () {
    test('parse empty', () {
      expect(ChatBadgeRef.parse(null), isEmpty);
      expect(ChatBadgeRef.parse(''), isEmpty);
    });
  });
}
