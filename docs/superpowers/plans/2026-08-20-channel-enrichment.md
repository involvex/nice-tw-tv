# Channel Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add channel panels & About section, VOD chapters parsing and navigation, watch history search, and theater mode to Nice TV.

**Architecture:** Extend existing features (`profile`, `vod`, `history`, `watch`) following the established `data/` + `presentation/` split. New pure parsing logic (panels model, VOD chapters JSON/Helix parsing, history search filter) lives in `data/` and is unit-tested; UI extensions live in `presentation/`.

**Tech Stack:** Flutter/Dart, Riverpod (`FutureProvider.family`, `Notifier`), Dio/Helix API, `go_router`, `CachedNetworkImage`.

## Global Constraints

- Flutter SDK `^3.13.0-282.1.beta`, Dart latest stable.
- Use `bun` only for non-Flutter tasks; this is a Flutter repo so use `flutter pub get`, `flutter test`, `flutter analyze`, `dart format .`.
- No new third-party dependencies.
- Follow existing naming: files `snake_case.dart`, classes `PascalCase`, private members `_`-prefixed.
- Follow the feature-based architecture: logic in `data/`, UI in `presentation/`.
- Use Riverpod `Notifier`/`FutureProvider`, never `ChangeNotifier`.
- Do not add comments to code unless a doc comment is genuinely needed.
- Commit after every task with conventional-commit messages (`feat:`).

---

## File Structure

- Create: `lib/features/profile/data/channel_panels.dart` — panel model + parser.
- Create: `lib/features/profile/presentation/channel_panels_section.dart` — channel panels & about section.
- Modify: `lib/features/profile/presentation/channel_profile_screen.dart` — wire panels & about.
- Create: `lib/features/vod/data/vod_chapters.dart` — VOD chapter model + parser.
- Modify: `lib/features/vod/presentation/vod_screen.dart` — VOD chapters sheet / list + jump-to.
- Modify: `lib/features/history/data/history_controller.dart` — search/filter query state + provider.
- Modify: `lib/features/history/presentation/history_screen.dart` — search bar for watch history.
- Modify: `lib/features/watch/presentation/watch_screen.dart` — theater mode toggle.
- Test: `test/unit/channel_panels_test.dart`
- Test: `test/unit/vod_chapters_test.dart`
- Test: `test/unit/history_search_test.dart`

---

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

### Task 2: VOD Chapters

**Files:**
- Create: `lib/features/vod/data/vod_chapters.dart`
- Modify: `lib/features/vod/presentation/vod_screen.dart`
- Test: `test/unit/vod_chapters_test.dart`

**Interfaces:**
- Produces: `class VodChapter { final String title; final int seekSeconds; }`; `VodChapters.fromJson(...)`.

- [ ] **Step 1: Write failing test, implement model & VOD screen chapter jump UI, test & commit.**

---

### Task 3: Search Within Watch History

**Files:**
- Modify: `lib/features/history/data/history_controller.dart`
- Modify: `lib/features/history/presentation/history_screen.dart`
- Test: `test/unit/history_search_test.dart`

**Interfaces:**
- Produces: `List<HistoryItem> filterHistory(List<HistoryItem> items, String query)`.

- [ ] **Step 1: Write failing test, implement search filter, add search bar to history screen, test & commit.**

---

### Task 4: Theater Mode Toggle

**Files:**
- Modify: `lib/features/watch/presentation/watch_screen.dart`

**Interfaces:**
- Produces: Theater mode layout variant in `WatchScreen`.

- [ ] **Step 1: Add theater mode toggle button in watch screen player header, update layout, analyze & commit.**

---

## Self-Review Checklist

- Spec coverage: 4.1 Channel Panels (Task 1), 5.1 VOD Chapters (Task 2), 11.9 Watch History Search (Task 3), 2.1 Theater Mode (Task 4).
- No placeholders.
- Type consistency verified.
