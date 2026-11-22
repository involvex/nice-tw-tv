import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/vod/data/twitch_vod.dart';
import 'package:nice_tv/features/watch/data/playback_handoff.dart';

void main() {
  TwitchVod vod(String id, {DateTime? createdAt}) => TwitchVod(
    id: id,
    userId: 'u1',
    userLogin: 'chan',
    userName: 'Chan',
    title: 'VOD $id',
    url: 'https://twitch.tv/videos/$id',
    thumbnailUrl: 'https://example.com/$id.jpg',
    viewCount: 1,
    duration: '1h0m0s',
    createdAt: createdAt ?? DateTime(2024, 1, 1),
    type: 'archive',
  );

  group('nextArchiveAfter', () {
    test('returns the next older archive', () {
      final vods = [vod('3'), vod('2'), vod('1')];
      expect(nextArchiveAfter(vods: vods, currentVodId: '3')?.id, '2');
      expect(nextArchiveAfter(vods: vods, currentVodId: '2')?.id, '1');
    });

    test('returns null at the end of the list', () {
      final vods = [vod('2'), vod('1')];
      expect(nextArchiveAfter(vods: vods, currentVodId: '1'), isNull);
    });

    test('falls back when current id is missing', () {
      final vods = [vod('a'), vod('b')];
      expect(nextArchiveAfter(vods: vods, currentVodId: 'missing')?.id, 'a');
    });
  });
}
