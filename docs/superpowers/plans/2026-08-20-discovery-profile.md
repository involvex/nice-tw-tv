# Discovery & Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a channel schedule section, a top-clips shelf, an offline-followed section, and a share button to the Nice TV profile/discovery experience.

**Architecture:** Extend the existing `profile` feature (`lib/features/profile/`) following the established `data/` + `presentation/` split. Schedule model + parsing and the offline-followed helper are pure logic in `data/` and are unit-tested; shelves follow the existing `SimilarStreamsShelf` self-contained `FutureProvider.family` + widget pattern. `getFollowedChannels` already exists on `HelixRepository`; `getClips` already exists. The offline section extends the `FollowingScreen` live feed.

**Tech Stack:** Flutter/Dart, Riverpod (`FutureProvider.family`, `Notifier`), Dio/Helix API, `go_router`, `share_plus` (already a dep), `CachedNetworkImage`.

## Global Constraints

- Flutter SDK `^3.13.0-282.1.beta`, Dart latest stable.
- Use `bun` only for non-Flutter tasks; this is a Flutter repo so use `flutter pub get`, `flutter test`, `flutter analyze`, `dart format .`.
- No new third-party dependencies; `share_plus` is already used in `lib/features/watch/presentation/watch_screen.dart:659` as `SharePlus.instance.share(ShareParams(text: url))` — reuse that API.
- Follow existing naming: files `snake_case.dart`, classes `PascalCase`, private members `_`-prefixed.
- Follow the feature-based architecture: logic in `data/`, UI in `presentation/`.
- Use Riverpod `Notifier`/`FutureProvider`, never `ChangeNotifier`.
- The schedule endpoint is the Helix `/helix/schedule` REST API (NOT GQL), consistent with `HelixRepository`.
- Do not add comments to code unless a doc comment is genuinely needed (matching existing style).
- Commit after every task with conventional-commit messages (`feat:`).

---

## File Structure

- Modify: `lib/features/home/data/helix_repository.dart` — add `getChannelSchedule`.
- Create: `lib/features/profile/data/channel_schedule.dart` — schedule model + `fromJson` + time-format helper.
- Create: `lib/features/profile/data/channel_schedule_controller.dart` — `FutureProvider.family` for schedule segments.
- Create: `lib/features/profile/presentation/channel_schedule_shelf.dart` — schedule shelf widget.
- Create: `lib/features/profile/presentation/channel_clips_shelf.dart` — top-clips shelf widget.
- Modify: `lib/features/profile/presentation/channel_profile_screen.dart` — wire shelves + share button.
- Create: `lib/features/home/data/offline_followed.dart` — offline-followed helper + provider.
- Create: `lib/features/home/presentation/offline_channels_section.dart` — offline channels section widget.
- Modify: `lib/features/home/presentation/following_screen.dart` — merge offline section into the feed scroll view.
- Test: `test/unit/channel_schedule_test.dart` — schedule model + formatting tests.
- Test: `test/unit/offline_followed_test.dart` — offline-followed helper tests.

---

### Task 1: Channel schedule — model + Helix method

**Files:**
- Create: `lib/features/profile/data/channel_schedule.dart`
- Modify: `lib/features/home/data/helix_repository.dart`
- Test: `test/unit/channel_schedule_test.dart`

**Interfaces:**
- Consumes: `helixDioProvider` (existing). Helix endpoint `GET /helix/schedule?broadcaster_id=&first=` returns `data[0].segments[]` where each segment has `id`, `start_time`, `end_time`, `title`, `category{id,name}`, `is_recurring`.
- Produces: `class ChannelScheduleSegment { final String id; final DateTime startTime; final DateTime endTime; final String title; final String categoryId; final String categoryName; final bool isRecurring; }`; `class ChannelSchedule { final List<ChannelScheduleSegment> segments; factory ChannelSchedule.fromJson(Map<String, dynamic>); }`; `String formatScheduleTime(DateTime)`; `HelixRepository.getChannelSchedule(String broadcasterId, {int first = 12})`.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/channel_schedule_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/profile/data/channel_schedule.dart';

void main() {
  group('ChannelSchedule.fromJson', () {
    test('parses segments', () {
      final schedule = ChannelSchedule.fromJson({
        'data': [
          {
            'segments': [
              {
                'id': 'seg1',
                'start_time': '2026-08-30T18:14:16Z',
                'end_time': '2026-08-30T18:34:16Z',
                'title': 'Playing Fortnite',
                'category': {'id': '33214', 'name': 'Fortnite'},
                'is_recurring': true,
              },
              {
                'id': 'seg2',
                'start_time': '2026-09-01T18:00:00Z',
                'end_time': '2026-09-01T19:00:00Z',
                'title': '',
                'category': null,
                'is_recurring': false,
              },
            ],
          },
        ],
      });
      expect(schedule.segments.length, 2);
      final first = schedule.segments.first;
      expect(first.id, 'seg1');
      expect(first.title, 'Playing Fortnite');
      expect(first.categoryId, '33214');
      expect(first.categoryName, 'Fortnite');
      expect(first.isRecurring, isTrue);
      expect(first.startTime.isUtc, isTrue);
    });

    test('handles empty payload', () {
      final schedule = ChannelSchedule.fromJson(const {'data': []});
      expect(schedule.segments, isEmpty);
    });
  });

  group('formatScheduleTime', () {
    test('formats a UTC time with day, month, and clock', () {
      final formatted = formatScheduleTime(
        DateTime.utc(2026, 8, 30, 18, 14),
      );
      expect(formatted, contains('Sun'));
      expect(formatted, contains('Aug'));
      expect(formatted, contains('30'));
      expect(formatted, contains('6:14 PM'));
    });

    test('formats midnight as 12:00 AM', () {
      final formatted = formatScheduleTime(DateTime.utc(2026, 8, 30, 0, 0));
      expect(formatted, contains('12:00 AM'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/channel_schedule_test.dart`
Expected: FAIL — `ChannelSchedule` and `formatScheduleTime` not defined.

- [ ] **Step 3: Implement the model**

Create `lib/features/profile/data/channel_schedule.dart`:

```dart
class ChannelScheduleSegment {
  const ChannelScheduleSegment({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.isRecurring,
  });

  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String categoryId;
  final String categoryName;
  final bool isRecurring;
}

class ChannelSchedule {
  const ChannelSchedule({required this.segments});

  final List<ChannelScheduleSegment> segments;

  factory ChannelSchedule.fromJson(Map<String, dynamic> json) {
    final entries = json['data'] as List<dynamic>? ?? const [];
    final segments = <ChannelScheduleSegment>[];
    for (final raw in entries) {
      final entry = raw as Map<String, dynamic>;
      final rawSegments = entry['segments'] as List<dynamic>? ?? const [];
      for (final segRaw in rawSegments) {
        final seg = segRaw as Map<String, dynamic>;
        final category = seg['category'] as Map<String, dynamic>?;
        segments.add(
          ChannelScheduleSegment(
            id: seg['id'] as String? ?? '',
            startTime:
                DateTime.tryParse(seg['start_time'] as String? ?? '') ??
                DateTime.now(),
            endTime:
                DateTime.tryParse(seg['end_time'] as String? ?? '') ??
                DateTime.now(),
            title: seg['title'] as String? ?? '',
            categoryId: category?['id'] as String? ?? '',
            categoryName: category?['name'] as String? ?? '',
            isRecurring: seg['is_recurring'] as bool? ?? false,
          ),
        );
      }
    }
    return ChannelSchedule(segments: segments);
  }
}

/// e.g. `Sun Aug 30 · 6:14 PM` in the device's local time zone.
String formatScheduleTime(DateTime t) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final local = t.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  final minute = local.minute.toString().padLeft(2, '0');
  return '${days[local.weekday - 1]} ${months[local.month - 1]} '
      '${local.day} · $hour12:$minute $ampm';
}
```

Note: the test asserts against `DateTime.utc(...)` but `formatScheduleTime` converts to local time first, so pass times such that the local rendering is deterministic is not guaranteed. To keep the test deterministic, change the assertions to construct the time via `DateTime(...)` (local) instead of `DateTime.utc(...)`. Use `DateTime(2026, 8, 30, 18, 14)` in the test so `Sun Aug 30 · 6:14 PM` holds regardless of time zone. (Step 1 above is written to be adjusted accordingly — the implementer must update the test's `DateTime.utc` calls to local `DateTime` constructors before running Step 2.)

- [ ] **Step 4: Add `getChannelSchedule` to `HelixRepository`**

In `lib/features/home/data/helix_repository.dart`, add the import at the top:

```dart
import 'package:nice_tv/features/profile/data/channel_schedule.dart';
```

Add the method after `getClips` (line 403):

```dart
  Future<ChannelSchedule> getChannelSchedule(
    String broadcasterId, {
    int first = 12,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/schedule',
      queryParameters: {'broadcaster_id': broadcasterId, 'first': first},
    );
    return ChannelSchedule.fromJson(response.data!);
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/unit/channel_schedule_test.dart`
Expected: PASS.

- [ ] **Step 6: Run analyze and commit**

Run: `flutter analyze lib/features/profile/data/channel_schedule.dart lib/features/home/data/helix_repository.dart`
Expected: No issues found.
Run: `dart format lib/features/profile/data/channel_schedule.dart lib/features/home/data/helix_repository.dart test/unit/channel_schedule_test.dart`
Run: `git add lib/features/profile/data/channel_schedule.dart lib/features/home/data/helix_repository.dart test/unit/channel_schedule_test.dart`
Run: `git commit -m "feat: add channel schedule model and Helix endpoint"`

---

### Task 2: Channel schedule shelf

**Files:**
- Create: `lib/features/profile/data/channel_schedule_controller.dart`
- Create: `lib/features/profile/presentation/channel_schedule_shelf.dart`

**Interfaces:**
- Consumes: `helixRepositoryProvider.getChannelSchedule` (Task 1).
- Produces: `channelScheduleProvider = FutureProvider.family<List<ChannelScheduleSegment>, String>` (arg = broadcasterId, filters to future segments, caps at 6); `class ChannelScheduleShelf extends ConsumerWidget { const ChannelScheduleShelf({required this.broadcasterId}); }` — display-only horizontal cards.

- [ ] **Step 1: Create the provider**

Create `lib/features/profile/data/channel_schedule_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/profile/data/channel_schedule.dart';

final channelScheduleProvider =
    FutureProvider.family<List<ChannelScheduleSegment>, String>((ref, id) async {
      if (id.isEmpty) return const [];
      final schedule = await ref
          .read(helixRepositoryProvider)
          .getChannelSchedule(id, first: 12);
      final now = DateTime.now();
      final upcoming = schedule.segments
          .where((s) => s.startTime.isAfter(now))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return upcoming.take(6).toList();
    });
```

- [ ] **Step 2: Create the shelf widget**

Create `lib/features/profile/presentation/channel_schedule_shelf.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/profile/data/channel_schedule.dart';
import 'package:nice_tv/features/profile/data/channel_schedule_controller.dart';

class ChannelScheduleShelf extends ConsumerWidget {
  const ChannelScheduleShelf({super.key, required this.broadcasterId});

  final String broadcasterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSegments = ref.watch(channelScheduleProvider(broadcasterId));
    final theme = Theme.of(context);

    return asyncSegments.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (segments) {
        if (segments.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Upcoming schedule', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: segments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final segment = segments[index];
                  return _ScheduleCard(segment: segment);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.segment});

  final ChannelScheduleSegment segment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatScheduleTime(segment.startTime),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              segment.title.isEmpty
                  ? (segment.categoryName.isEmpty
                        ? 'Untitled segment'
                        : segment.categoryName)
                  : segment.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Wire the shelf into the channel profile**

In `lib/features/profile/presentation/channel_profile_screen.dart`, add the import:

```dart
import 'package:nice_tv/features/profile/presentation/channel_schedule_shelf.dart';
```

Inside the main `Column` children, immediately after the `SimilarStreamsShelf(...)` block (lines 267–272), insert:

```dart
                        ChannelScheduleShelf(broadcasterId: user.id),
```

- [ ] **Step 4: Run analyze and commit**

Run: `flutter analyze lib/features/profile/data/channel_schedule_controller.dart lib/features/profile/presentation/channel_schedule_shelf.dart lib/features/profile/presentation/channel_profile_screen.dart`
Expected: No issues found.
Run: `dart format lib/features/profile/data/channel_schedule_controller.dart lib/features/profile/presentation/channel_schedule_shelf.dart lib/features/profile/presentation/channel_profile_screen.dart`
Run: `git add lib/features/profile/data/channel_schedule_controller.dart lib/features/profile/presentation/channel_schedule_shelf.dart lib/features/profile/presentation/channel_profile_screen.dart`
Run: `git commit -m "feat: add upcoming schedule shelf to channel profile"`

---

### Task 3: Top-clips shelf on the channel profile

**Files:**
- Create: `lib/features/profile/presentation/channel_clips_shelf.dart`
- Modify: `lib/features/profile/presentation/channel_profile_screen.dart`

**Interfaces:**
- Consumes: `helixRepositoryProvider.getClips(broadcasterId:)` (exists), `TwitchClip` model, `/clip/:id` route (exists in `app_router.dart`).
- Produces: `channelClipsProvider = FutureProvider.family<List<TwitchClip>, String>`; `class ChannelClipsShelf extends ConsumerWidget { const ChannelClipsShelf({required this.broadcasterId}); }` — horizontal cards pushing `/clip/<id>?title=&login=`.

- [ ] **Step 1: Create the shelf widget**

Create `lib/features/profile/presentation/channel_clips_shelf.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_clip.dart';

final channelClipsProvider =
    FutureProvider.family<List<TwitchClip>, String>((ref, id) async {
      if (id.isEmpty) return const [];
      final page = await ref
          .read(helixRepositoryProvider)
          .getClips(broadcasterId: id, first: 12);
      return page.clips;
    });

class ChannelClipsShelf extends ConsumerWidget {
  const ChannelClipsShelf({super.key, required this.broadcasterId});

  final String broadcasterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClips = ref.watch(channelClipsProvider(broadcasterId));
    final theme = Theme.of(context);

    return asyncClips.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (clips) {
        if (clips.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Top clips', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: clips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final clip = clips[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final uri = Uri(
                        path: '/clip/${clip.id}',
                        queryParameters: {
                          'title': clip.title,
                          'login': clip.broadcasterName,
                        },
                      );
                      context.push(uri.toString());
                    },
                    child: SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: CachedNetworkImage(
                                imageUrl: clip.sizedThumbnail(
                                  width: 220,
                                  height: 124,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            clip.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_formatViews(clip.viewCount)} views',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatViews(int count) {
    if (count >= 1000) {
      final value = count / 1000;
      return value.toStringAsFixed(value >= 10 ? 0 : 1);
    }
    return '$count';
  }
}
```

- [ ] **Step 2: Wire the shelf into the channel profile**

In `lib/features/profile/presentation/channel_profile_screen.dart`, add the import:

```dart
import 'package:nice_tv/features/profile/presentation/channel_clips_shelf.dart';
```

Inside the main `Column` children, immediately after the `ChannelScheduleShelf` inserted in Task 2, insert:

```dart
                        ChannelClipsShelf(broadcasterId: user.id),
```

- [ ] **Step 3: Run analyze and commit**

Run: `flutter analyze lib/features/profile/presentation/channel_clips_shelf.dart lib/features/profile/presentation/channel_profile_screen.dart`
Expected: No issues found.
Run: `dart format lib/features/profile/presentation/channel_clips_shelf.dart lib/features/profile/presentation/channel_profile_screen.dart`
Run: `git add lib/features/profile/presentation/channel_clips_shelf.dart lib/features/profile/presentation/channel_profile_screen.dart`
Run: `git commit -m "feat: add top clips shelf to channel profile"`

---

### Task 4: Share channel profile

**Files:**
- Modify: `lib/features/profile/presentation/channel_profile_screen.dart`

**Interfaces:**
- Consumes: `share_plus` (already a dep; API confirmed at `watch_screen.dart:659`).
- Produces: a share `IconButton.filledTonal` in the profile action row sharing `https://www.twitch.tv/<login>`.

- [ ] **Step 1: Add the share button**

In `lib/features/profile/presentation/channel_profile_screen.dart`, add the import:

```dart
import 'package:share_plus/share_plus.dart';
```

Inside the button `Row` (lines 154–238), immediately after the notifications `IconButton.filledTonal` (lines 214–221), insert:

```dart
                                        IconButton.filledTonal(
                                          tooltip: 'Share channel',
                                          onPressed: () async {
                                            await SharePlus.instance.share(
                                              ShareParams(
                                                text:
                                                    'https://www.twitch.tv/${user.login}',
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.share_outlined),
                                        ),
```

- [ ] **Step 2: Run analyze and commit**

Run: `flutter analyze lib/features/profile/presentation/channel_profile_screen.dart`
Expected: No issues found.
Run: `dart format lib/features/profile/presentation/channel_profile_screen.dart`
Run: `git add lib/features/profile/presentation/channel_profile_screen.dart`
Run: `git commit -m "feat: share channel profile via share sheet"`

---

### Task 5: Offline-followed section

**Files:**
- Create: `lib/features/home/data/offline_followed.dart`
- Create: `lib/features/home/presentation/offline_channels_section.dart`
- Modify: `lib/features/home/presentation/following_screen.dart`
- Test: `test/unit/offline_followed_test.dart`

**Interfaces:**
- Consumes: `getFollowedChannels(userId:, first: 200)` (exists), `followingFeedControllerProvider`, `/profile/:login` route (exists).
- Produces: `offlineFollowedChannelsProvider = FutureProvider.autoDispose<List<FollowedChannel>>`; `List<FollowedChannel> offlineFollowed(List<FollowedChannel> all, Set<String> liveUserIds)`; `class OfflineChannelsSection extends ConsumerWidget`.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/offline_followed_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/home/data/offline_followed.dart';

void main() {
  group('offlineFollowed', () {
    test('keeps channels not currently live', () {
      final all = [
        (id: '1', login: 'a', displayName: 'A'),
        (id: '2', login: 'b', displayName: 'B'),
        (id: '3', login: 'c', displayName: 'C'),
      ];
      final offline = offlineFollowed(all, {'2'});
      expect(offline.map((c) => c.login), ['a', 'c']);
    });

    test('returns all when nothing is live', () {
      final all = [
        (id: '1', login: 'a', displayName: 'A'),
        (id: '2', login: 'b', displayName: 'B'),
      ];
      expect(offlineFollowed(all, {}).length, 2);
    });

    test('returns empty when everything is live', () {
      final all = [
        (id: '1', login: 'a', displayName: 'A'),
      ];
      expect(offlineFollowed(all, {'1'}), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/offline_followed_test.dart`
Expected: FAIL — `offline_followed.dart` not defined.

- [ ] **Step 3: Implement the helper + provider**

Create `lib/features/home/data/offline_followed.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';

typedef FollowedChannel = ({String id, String login, String displayName});

final offlineFollowedChannelsProvider =
    FutureProvider.autoDispose<List<FollowedChannel>>((ref) async {
      final auth = ref.watch(authControllerProvider).value;
      if (auth?.isLoggedIn != true || auth?.userId == null) return const [];
      return ref
          .read(helixRepositoryProvider)
          .getFollowedChannels(userId: auth!.userId!, first: 200);
    });

/// Channels the user follows that are not currently live.
List<FollowedChannel> offlineFollowed(
  List<FollowedChannel> all,
  Set<String> liveUserIds,
) {
  return all.where((c) => !liveUserIds.contains(c.id)).toList();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/offline_followed_test.dart`
Expected: PASS.

- [ ] **Step 5: Create the offline channels section widget**

Create `lib/features/home/presentation/offline_channels_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/offline_followed.dart';

class OfflineChannelsSection extends ConsumerWidget {
  const OfflineChannelsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncAll = ref.watch(offlineFollowedChannelsProvider);
    final feed = ref.watch(followingFeedControllerProvider);
    final liveIds = feed.streams.map((s) => s.userId).toSet();
    final all = asyncAll.valueOrNull ?? const <FollowedChannel>[];
    final offline = offlineFollowed(all, liveIds);
    if (offline.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('More channels you follow', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final channel in offline)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                channel.displayName.isNotEmpty
                    ? channel.displayName[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(
              channel.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('@${channel.login}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/${channel.login}'),
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: Merge the offline section into the Following screen**

In `lib/features/home/presentation/following_screen.dart`, add the import:

```dart
import 'package:nice_tv/features/home/presentation/offline_channels_section.dart';
```

Replace the whole ternary branch of `RefreshIndicator.child` (lines 60–120) with a single scrollable `ListView`:

```dart
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (feed.isLoading && feed.streams.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (feed.error != null && feed.streams.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(feed.error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => ref
                                .read(
                                  followingFeedControllerProvider.notifier,
                                )
                                .refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (feed.streams.isEmpty)
                    SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No followed live channels right now.',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    )
                  else
                    for (final stream in feed.streams)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: StreamCard(stream: stream),
                      ),
                  if (feed.cursor != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  OfflineChannelsSection(),
                ],
              ),
```

Note: the load-more sentinel previously rendered only when `index >= feed.streams.length`; in the new layout it is a trailing child that appears whenever `feed.cursor != null`. To preserve the trigger, add `ref.read(followingFeedControllerProvider.notifier).loadMore();` via a `_LoadMoreProbe` widget that calls it in `initState`, or invoke it in `didChangeDependencies`. Concretely, replace the `if (feed.cursor != null) Padding(...)` block above with:

```dart
                  if (feed.cursor != null)
                    const _LoadMoreProbe(),
```

and add this small widget at the bottom of `following_screen.dart`:

```dart
class _LoadMoreProbe extends ConsumerStatefulWidget {
  const _LoadMoreProbe();

  @override
  ConsumerState<_LoadMoreProbe> createState() => _LoadMoreProbeState();
}

class _LoadMoreProbeState extends ConsumerState<_LoadMoreProbe> {
  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    ref.read(followingFeedControllerProvider.notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
```

- [ ] **Step 7: Run analyze to verify compile**

Run: `flutter analyze lib/features/home/data/offline_followed.dart lib/features/home/presentation/offline_channels_section.dart lib/features/home/presentation/following_screen.dart`
Expected: No issues found.

- [ ] **Step 8: Format and commit**

Run: `dart format lib/features/home/data/offline_followed.dart lib/features/home/presentation/offline_channels_section.dart lib/features/home/presentation/following_screen.dart test/unit/offline_followed_test.dart`
Run: `git add lib/features/home/data/offline_followed.dart lib/features/home/presentation/offline_channels_section.dart lib/features/home/presentation/following_screen.dart test/unit/offline_followed_test.dart`
Run: `git commit -m "feat: show offline followed channels on the Following screen"`

---

### Task 6: Full verification

**Files:**
- All files touched above.

- [x] **Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass (existing + new).

- [x] **Step 2: Run analyzer on the whole repo**

Run: `flutter analyze`
Expected: No issues found.

- [x] **Step 3: Format**

Run: `dart format .`
Expected: No diffs (already formatted).

---

### Task 6 verification results

- `flutter test`: 42 tests passed (new schedule + offline tests included).
- `flutter analyze`: No issues found.
- `dart format .`: 76 files, 0 changed.
- Note: `formatScheduleTime` tests use local `DateTime(...)` constructors per the plan's determinism note.

## Self-Review Checklist

- Spec coverage: 11.4 Stream schedule (Tasks 1, 2), 11.5 Clips tab on profile (Task 3), 3.3 Offline-followed filter (Task 5), 4.3 Share profile (Task 4). All covered.
- No placeholders: every task has concrete code and exact commands.
- Type consistency: `ChannelSchedule.fromJson`, `formatScheduleTime`, `getChannelSchedule`, `channelScheduleProvider`, `channelClipsProvider`, `offlineFollowedChannelsProvider`, `offlineFollowed`, `OfflineChannelsSection` are each defined once and reused consistently.
- Existing routes reused (`/clip/:id`, `/profile/:login`, `/watch/:login`); no router changes required.