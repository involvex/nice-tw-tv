# Category Browse from Frontpage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to tap a category chip on the Live tab frontpage and navigate to a dedicated category browse screen that uses the same card-based infinite scroll layout as the frontpage (not the ListTile-based `CategoryStreamsScreen`).

**Architecture:** 
- Create a new `CategoryBrowseScreen` that reuses the frontpage's feed controller pattern but filtered to a single game/category
- The screen will use `StreamCard` widgets in a `SliverList` with infinite scroll, matching the frontpage UI exactly
- Add navigation from `_CategoryChips` to this new screen via the existing `/category/:id` route
- Deprecate the existing `CategoryStreamsScreen` (ListTile-based) in favor of the new card-based screen

**Tech Stack:** Flutter, Riverpod (NotifierProvider), GoRouter, Dio (Twitch Helix API)

## Global Constraints

- Use `flutter_riverpod` ^3.3.2 for state management (Notifier/AsyncNotifier pattern)
- Use `go_router` ^17.3.0 for navigation
- Follow existing code style: `dart format .`, `flutter analyze` must pass
- Use `CachedNetworkImage` for thumbnails, `StreamCard` widget for stream items
- Keep providers small and focused; prefer `NotifierProvider.autoDispose` for screen-scoped state
- Android-first app but must work on iOS too

---

## File Map

| File | Responsibility |
|------|----------------|
| `lib/features/home/presentation/category_browse_screen.dart` | **NEW** - Dedicated category browse screen with card-based infinite scroll |
| `lib/features/home/presentation/home_screen.dart` | **MODIFY** - Update `_CategoryChips` to navigate to new screen |
| `lib/core/routing/app_router.dart` | **MODIFY** - Update `/category/:id` route to use new screen |
| `lib/features/home/presentation/autoplay_feed.dart` | **MODIFY** - Mark `CategoryStreamsScreen` as deprecated |
| `lib/features/home/data/helix_repository.dart` | **EXISTING** - Already has `getStreamsByGame` method |

---

### Task 1: Create CategoryBrowseScreen with card-based infinite scroll

**Files:**
- Create: `lib/features/home/presentation/category_browse_screen.dart`
- Test: `test/unit/category_browse_screen_test.dart` (optional widget test)

**Interfaces:**
- Consumes: `helixRepositoryProvider`, `settingsControllerProvider`, route parameters (`gameId`, `name`)
- Produces: A `ConsumerStatefulWidget` that displays streams for a specific category using `StreamCard` widgets in a `SliverList` with infinite scroll

- [ ] **Step 1: Write the failing widget test**

```dart
// test/unit/category_browse_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/presentation/category_browse_screen.dart';

void main() {
  testWidgets('CategoryBrowseScreen shows loading then streams', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CategoryBrowseScreen(gameId: 'test-game-id', name: 'Test Game'),
        ),
      ),
    );
    // Initially shows loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/category_browse_screen_test.dart`
Expected: FAIL - file doesn't exist yet

- [ ] **Step 3: Create CategoryBrowseScreen implementation**

```dart
// lib/features/home/presentation/category_browse_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/home/presentation/home_screen.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';

class CategoryBrowseScreen extends ConsumerStatefulWidget {
  const CategoryBrowseScreen({
    super.key,
    required this.gameId,
    required this.name,
  });

  final String gameId;
  final String name;

  @override
  ConsumerState<CategoryBrowseScreen> createState() => _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends ConsumerState<CategoryBrowseScreen> {
  var _streams = <TwitchStream>[];
  String? _cursor;
  var _loading = true;
  var _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final settings = ref.read(settingsControllerProvider);
      final page = await ref
          .read(helixRepositoryProvider)
          .getStreamsByGame(
            gameId: widget.gameId,
            cursor: more ? _cursor : null,
            language: settings.discoveryLanguage,
            type: 'live',
          );
      final filtered = HelixRepository.applyDiscoveryFilters(
        streams: page.streams,
        language: settings.discoveryLanguage,
        hideMature: settings.discoveryHideMature,
        sortOrder: settings.discoverySortOrder,
      );
      setState(() {
        _streams = more ? [..._streams, ...filtered] : filtered;
        _cursor = page.cursor;
        _loading = false;
        _loadingMore = false;
      });
    } on Object catch (e) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _onRefresh() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _loading && _streams.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null && _streams.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _onRefresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _streams.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 200,
                            child: Center(
                              child: Text(
                                'No live streams in ${widget.name}.',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _streams.length + (_cursor != null ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          if (index >= _streams.length) {
                            _load(more: true);
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return StreamCard(stream: _streams[index]);
                        },
                      ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/category_browse_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Run static analysis and format**

Run: `dart format . && flutter analyze`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/presentation/category_browse_screen.dart
git commit -m "feat: add CategoryBrowseScreen with card-based infinite scroll"
```

---

### Task 2: Update app_router.dart to use CategoryBrowseScreen

**Files:**
- Modify: `lib/core/routing/app_router.dart:85-92`

**Interfaces:**
- Consumes: `CategoryBrowseScreen` from Task 1
- Produces: Updated route that uses the new screen

- [ ] **Step 1: Update the route import and builder**

```dart
// lib/core/routing/app_router.dart
// Add import at top:
import 'package:nice_tv/features/home/presentation/category_browse_screen.dart';

// Replace the existing /category/:id route (lines 85-92):
GoRoute(
  path: '/category/:id',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    final name = state.uri.queryParameters['name'] ?? 'Category';
    return CategoryBrowseScreen(gameId: id, name: name);
  },
),
```

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/core/routing/app_router.dart
git commit -m "feat: route /category/:id to CategoryBrowseScreen"
```

---

### Task 3: Update _CategoryChips in home_screen.dart to navigate on tap

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart:314-376`

**Interfaces:**
- Consumes: `context.push` for navigation, `homeCategoryFilterProvider` for filter state
- Produces: Updated `_CategoryChips` that navigates to `/category/:id` on tap while keeping the filter selection visual

- [ ] **Step 1: Modify _CategoryChips to navigate on tap**

```dart
// lib/features/home/presentation/home_screen.dart
// In _CategoryChips.build, update the FilterChip onSelected:

// For "All" chip (line 335-343):
Padding(
  padding: const EdgeInsets.only(right: 8),
  child: FilterChip(
    label: const Text('All'),
    selected: selected == null,
    onSelected: (_) => ref
        .read(homeCategoryFilterProvider.notifier)
        .select(null),
  ),
),

// For category chips (lines 345-369):
for (final category in list)
  Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(category.name),
      selected: selected?.id == category.id,
      avatar: category.boxArtUrl.isEmpty
          ? null
          : CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(
                category.sizedBoxArt(width: 52, height: 72),
              ),
            ),
      onSelected: (_) {
        final notifier = ref.read(homeCategoryFilterProvider.notifier);
        if (selected?.id == category.id) {
          notifier.select(null);
        } else {
          notifier.select(category);
          // Navigate to dedicated category browse screen
          context.push('/category/${category.id}?name=${Uri.encodeComponent(category.name)}');
        }
      },
    ),
  ),
```

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/home_screen.dart
git commit -m "feat: navigate to CategoryBrowseScreen from category chips"
```

---

### Task 4: Mark CategoryStreamsScreen as deprecated

**Files:**
- Modify: `lib/features/home/presentation/autoplay_feed.dart:152-247`

**Interfaces:**
- Consumes: None (just adding deprecation notice)
- Produces: Deprecated class with migration comment

- [ ] **Step 1: Add deprecation annotation and comment**

```dart
// lib/features/home/presentation/autoplay_feed.dart
// Replace lines 152-165:
/// @deprecated Use [CategoryBrowseScreen] instead which provides the same
/// card-based infinite scroll layout as the frontpage.
/// This class will be removed in a future version.
@Deprecated('Use CategoryBrowseScreen instead')
class CategoryStreamsScreen extends ConsumerStatefulWidget {
  // ... rest unchanged
}
```

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: No errors (deprecation warning is fine)

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/autoplay_feed.dart
git commit -m "chore: deprecate CategoryStreamsScreen in favor of CategoryBrowseScreen"
```

---

### Task 5: Integration test and verification

**Files:**
- No new files, manual verification

**Interfaces:**
- Consumes: All previous tasks
- Produces: Verified working feature

- [ ] **Step 1: Run the app and test manually**

```bash
flutter run
```

Verify:
1. Open app to Live tab
2. Scroll category chips horizontally
3. Tap a category chip (e.g., "New World", "Just Chatting")
4. Should navigate to new screen with:
   - App bar showing category name
   - Card-based stream list (same as frontpage)
   - Infinite scroll loads more streams
   - Pull-to-refresh works
   - Stream cards tap to open watch screen

- [ ] **Step 2: Run existing tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete category browse from frontpage with card-based infinite scroll"
```

---

## Self-Review Checklist

- [ ] Spec coverage: User can select category from chips → navigates to dedicated screen → same card-based infinite scroll as frontpage
- [ ] No placeholders: All code blocks are complete and runnable
- [ ] Type consistency: `CategoryBrowseScreen` uses `StreamCard` from `home_screen.dart`, imports match
- [ ] Existing patterns followed: Same `StreamFeedState` pattern, same `HelixRepository.applyDiscoveryFilters`, same `StreamCard` widget
- [ ] Deprecation handled: Old `CategoryStreamsScreen` marked deprecated with migration path

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-12-category-browse-frontpage.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**