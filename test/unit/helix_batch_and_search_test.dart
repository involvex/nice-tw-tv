import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';

TwitchStream _stream({
  required String userId,
  String login = 'login',
  String name = 'Name',
  int viewers = 0,
  String thumb = '',
  String title = 'title',
}) {
  return TwitchStream(
    id: 'sid-$userId',
    userId: userId,
    userLogin: login,
    userName: name,
    gameName: 'Game',
    gameId: '1',
    title: title,
    viewerCount: viewers,
    thumbnailUrl: thumb,
    startedAt: DateTime.utc(2024, 1, 1),
    isMature: false,
    language: 'en',
  );
}

void main() {
  group('batchHelixIds', () {
    test('keeps every id across batches instead of collapsing keys', () {
      final ids = List.generate(250, (i) => 'id-$i');
      final batches = batchHelixIds(ids, 100);
      expect(batches.length, 3);
      expect(batches[0].length, 100);
      expect(batches[1].length, 100);
      expect(batches[2].length, 50);
      expect(batches.expand((b) => b).toList(), ids);
    });

    test('drops empty ids', () {
      expect(batchHelixIds(['a', '', 'b'], 100), [
        ['a', 'b'],
      ]);
    });

    test('returns empty for empty input', () {
      expect(batchHelixIds([], 100), isEmpty);
    });
  });

  group('mergeSearchWithLiveStreams', () {
    test('prefers live viewers and stream thumbnail', () {
      final hits = [
        _stream(
          userId: '1',
          login: 'alice',
          thumb: 'https://profile/alice.png',
        ),
        _stream(userId: '2', login: 'bob', thumb: 'https://profile/bob.png'),
      ];
      final live = [
        _stream(
          userId: '1',
          login: 'alice',
          viewers: 1234,
          thumb:
              'https://static-cdn.jtvnw.net/previews-ttv/live_user_alice-{width}x{height}.jpg',
          title: 'Live now',
        ),
      ];
      final merged = mergeSearchWithLiveStreams(hits, live);
      expect(merged.length, 1);
      expect(merged.first.userId, '1');
      expect(merged.first.viewerCount, 1234);
      expect(merged.first.thumbnailUrl, contains('previews-ttv'));
      expect(merged.first.title, 'Live now');
    });

    test('preserves search order of still-live hits', () {
      final hits = [
        _stream(userId: 'a'),
        _stream(userId: 'b'),
        _stream(userId: 'c'),
      ];
      final live = [
        _stream(userId: 'c', viewers: 3),
        _stream(userId: 'a', viewers: 1),
      ];
      expect(mergeSearchWithLiveStreams(hits, live).map((s) => s.userId), [
        'a',
        'c',
      ]);
    });

    test('maps Search Channels JSON fields used for hits', () {
      final hit = TwitchStream.fromJson({
        'id': '123',
        'broadcaster_login': 'coolstreamer',
        'display_name': 'CoolStreamer',
        'game_id': '509658',
        'game_name': 'Just Chatting',
        'title': 'Hello',
        'thumbnail_url':
            'https://static-cdn.jtvnw.net/jtv_user_pictures/abc.png',
        'is_live': true,
        'started_at': '2024-06-01T12:00:00Z',
        'broadcaster_language': 'en',
      });
      expect(hit.userId, '123');
      expect(hit.userLogin, 'coolstreamer');
      expect(hit.viewerCount, 0);
      expect(hit.thumbnailUrl, contains('jtv_user_pictures'));
    });
  });
}
