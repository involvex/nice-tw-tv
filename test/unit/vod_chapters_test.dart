import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/vod/data/vod_chapters.dart';

void main() {
  group('VodChapters', () {
    test('parses json correctly', () {
      final json = {
        'data': [
          {'title': 'Intro', 'seek_seconds': 0},
          {'title': 'Gameplay', 'seek_seconds': 300},
          {'seekSeconds': 600, 'title': 'Outro'},
        ],
      };

      final vodChapters = VodChapters.fromJson(json);
      expect(vodChapters.chapters.length, 3);
      expect(vodChapters.chapters[0].title, 'Intro');
      expect(vodChapters.chapters[0].seekSeconds, 0);
      expect(vodChapters.chapters[1].title, 'Gameplay');
      expect(vodChapters.chapters[1].seekSeconds, 300);
      expect(vodChapters.chapters[2].title, 'Outro');
      expect(vodChapters.chapters[2].seekSeconds, 600);
    });
  });
}
