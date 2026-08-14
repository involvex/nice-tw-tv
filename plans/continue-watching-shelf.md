# Implementation Plan: Continue Watching Shelf

## Overview
Add a "Continue Watching" shelf to the home screen (and optionally the VOD tab) that surfaces VODs the user has started but not finished. The existing `VodProgressStore` already tracks playback positions in `SharedPreferences`; this plan extends it to also persist minimal VOD metadata so the shelf can render without extra API calls.

## Scope
- **New widget:** `ContinueWatchingShelf` on the home screen
- **Data layer:** Extend `VodProgressStore` to store VOD metadata alongside position
- **State layer:** New `continueWatchingProvider` that exposes a sorted list of in-progress VODs
- **UI:** Horizontal scrollable shelf with resume buttons and progress indicators

## Existing Touchpoints
- `lib/features/vod/data/vod_progress_store.dart` — stores `vodId -> position` in `SharedPreferences`
- `lib/features/watch/presentation/watch_screen.dart` — saves/clears positions via `vodProgressStoreProvider`
- `lib/features/home/presentation/home_screen.dart` — hosts the live/clips feed; the shelf will be inserted here
- `lib/features/vod/presentation/vod_screen.dart` — VOD tab; optional second placement for the shelf
- `lib/core/routing/app_router.dart` — `/vod/:id` route used for resume navigation

## Steps

### 1. Extend VodProgressStore data model
- Change the stored value from `Map<String, int>` (id → ms) to a JSON object that also captures:
  - `title`
  - `userName`
  - `userLogin`
  - `thumbnailUrl`
  - `duration` (for progress-bar math)
- Add a small DTO, e.g. `VodProgressEntry`, with `vodId`, `position`, and the metadata fields above.
- Keep backward-compatible migration: if the old flat map is present, convert it to entries with empty metadata so the shelf can still render (metadata will be missing until the user re-opens the VOD).

### 2. Update WatchScreen to persist metadata
- When a VOD first starts (`widget.vodId != null`), save the VOD metadata into `VodProgressStore` together with the position.
- Currently `_schedulePositionSave` only saves position. Add a one-time metadata save in `initState` (guarded so it does not overwrite on every rebuild).

### 3. Create continueWatchingProvider
- New file: `lib/features/vod/data/continue_watching_provider.dart`
- Provider reads `vodProgressStoreProvider`, filters entries where `position > 0` and `position < duration - 10s`, and sorts by most recently saved position (newest first).
- Exposes `List<VodProgressEntry>`.

### 4. Build ContinueWatchingShelf widget
- New file: `lib/features/home/presentation/continue_watching_shelf.dart`
- Horizontal `ListView` of small cards (matching existing `StreamCard` / `ClipCard` aesthetic).
- Each card shows:
  - Thumbnail (16:9)
  - Title (1 line)
  - Channel name
  - Linear progress indicator showing `position / duration`
  - "Resume" button or tap-to-resume behavior
- Empty state: hidden when the list is empty.

### 5. Integrate into HomeScreen
- In `home_screen.dart`, insert `ContinueWatchingShelf` as a `SliverToBoxAdapter` above the tab bar (or below it, depending on UX preference).
- Place it only when `homeBrowseTabProvider` is `HomeBrowseTab.live` so it does not clutter the Clips tab.
- Wrap with `SliverToBoxAdapter` + `SizedBox(height: ...)` for spacing.

### 6. Wire resume navigation
- Tapping a shelf card navigates to `/vod/:id?title=...&login=...&userId=...`.
- The `WatchScreen` already reads `vodProgressStoreProvider` in `initState` and sets `_resumePosition`, so no changes needed there.

### 7. Handle completion cleanup
- In `watch_screen.dart` `_schedulePositionSave`, the existing logic already clears the entry when the user is within 10 seconds of the end. That remains unchanged.
- Optionally add a manual "Mark as watched" / clear action on long-press of a shelf card.

## Files to Modify
- `lib/features/vod/data/vod_progress_store.dart`
- `lib/features/watch/presentation/watch_screen.dart`
- `lib/features/home/presentation/home_screen.dart`
- New: `lib/features/vod/data/continue_watching_provider.dart`
- New: `lib/features/home/presentation/continue_watching_shelf.dart`

## Testing Considerations
- Unit test `VodProgressStore` round-trip with the new metadata schema.
- Unit test `continueWatchingProvider` filtering and sorting logic.
- Widget test `ContinueWatchingShelf` renders empty state and populated state correctly.
- Manual test: start a VOD, seek to middle, go back to home, verify shelf appears, tap to resume.

## Risks / Notes
- Metadata stored in `SharedPreferences` is not encrypted; acceptable for non-sensitive VOD titles/usernames.
- If the user watches the same VOD on multiple devices, progress will be local-only until a cloud-sync layer is added.
- Thumbnail URLs from Twitch are short-lived; if the shelf is rendered much later, images may need a fallback. `CachedNetworkImage` already handles errors gracefully.
