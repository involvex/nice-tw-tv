import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/profile/data/channel_panels.dart';

void main() {
  test('parses channel panels from json', () {
    final panels = ChannelPanels.fromJson({
      'data': [
        {
          'title': 'Rules',
          'link_url': 'https://twitch.tv',
          'image_url': 'https://img.png',
        },
      ],
    });
    expect(panels.panels.length, 1);
    expect(panels.panels.first.title, 'Rules');
    expect(panels.panels.first.linkUrl, 'https://twitch.tv');
  });
}
