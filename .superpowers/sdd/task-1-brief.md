### Task 1: Channel Panels & About Section

**Files:**
- Create: `lib/features/profile/data/channel_panels.dart`
- Create: `lib/features/profile/presentation/channel_panels_section.dart`
- Modify: `lib/features/profile/presentation/channel_profile_screen.dart`
- Test: `test/unit/channel_panels_test.dart`

**Interfaces:**
- Consumes: Helix `/helix/channels` or channel info / GQL extensions (or mock/fallback extension panels endpoint).
- Produces: `class ChannelPanel { final String title; final String linkUrl; final String imageUrl; }`; `ChannelPanels.fromJson(Map<String, dynamic>)`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/channel_panels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/profile/data/channel_panels.dart';

void main() {
  test('parses channel panels from json', () {
    final panels = ChannelPanels.fromJson({
      'data': [
        {'title': 'Rules', 'link_url': 'https://twitch.tv', 'image_url': 'https://img.png'}
      ]
    });
    expect(panels.panels.length, 1);
    expect(panels.panels.first.title, 'Rules');
    expect(panels.panels.first.linkUrl, 'https://twitch.tv');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/channel_panels_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement channel panels model**

Create `lib/features/profile/data/channel_panels.dart`:

```dart
class ChannelPanel {
  const ChannelPanel({
    required this.title,
    required this.linkUrl,
    required this.imageUrl,
  });

  final String title;
  final String linkUrl;
  final String imageUrl;
}

class ChannelPanels {
  const ChannelPanels({required this.panels});

  final List<ChannelPanel> panels;

  factory ChannelPanels.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? const [];
    final panels = <ChannelPanel>[];
    for (final raw in list) {
      final item = raw as Map<String, dynamic>;
      panels.add(
        ChannelPanel(
          title: item['title'] as String? ?? '',
          linkUrl: item['link_url'] as String? ?? item['url'] as String? ?? '',
          imageUrl: item['image_url'] as String? ?? '',
        ),
      );
    }
    return ChannelPanels(panels: panels);
  }
}
```

- [ ] **Step 4: Create panel section widget & wire into profile**

Create `lib/features/profile/presentation/channel_panels_section.dart` and add to `channel_profile_screen.dart`.

- [ ] **Step 5: Run tests and commit**

Run: `flutter test`
Run: `git add lib/features/profile/ test/unit/channel_panels_test.dart`
Run: `git commit -m "feat: add channel panels and about section"`

---

