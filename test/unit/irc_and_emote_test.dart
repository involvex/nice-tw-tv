import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';
import 'package:nice_tv/features/emotes/data/emote.dart';

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
  });
}
