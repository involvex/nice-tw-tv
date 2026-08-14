# Plan: Playback Speed, Resume VOD Position, Share Stream

## Context

Three next features from `suggestions.md`:
- **2.3 Resume VOD from Last Position** (High priority)
- **2.1 Playback Speed Control** (Medium priority)
- **5.2 Share Stream / Clip** (Medium priority)

All build on the patterns established by the volume/muted fix and followed-categories feature already implemented.

---

## 1. Resume VOD from Last Position (suggestion 2.3)

### Goal

When a user reopens a VOD, seek to the last watched position (e.g. where they stopped or where the app was closed). Periodically save the position while playing. Only apply to VODs (not live streams).

### Affected Files

- **New:** `lib/features/vod/data/vod_progress_store.dart` — read/write position per vodId in SharedPreferences
- `lib/features/watch/presentation/watch_screen.dart` — pass saved position, periodic save, seek on load
- `lib/features/watch/presentation/native_hls_player.dart` — accept `resumePosition`, add `seek()`, `getCurrentPosition()`, `setRate()`, `setPlaybackSpeed()` methods
- `lib/features/watch/presentation/twitch_embed_player.dart` — accept `resumePosition`, add `seek()` via JS bridge
- `lib/core/storage/app_storage.dart` — add `vodProgressKey` storage

### Design

#### VodProgressStore (`vod_progress_store.dart`)
```dart
class VodProgressStore {
  VodProgressStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'vod_progress';
  Map<String, int> readAll();  // vodId -> milliseconds
  Future<void> savePosition(String vodId, Duration position);
  Duration? readPosition(String vodId);
  Future<void> clear(String vodId);
}
```

Reuse the existing `sharedPreferencesProvider` pattern (like `HistoryStore` does via `settingsStorageProvider`).

#### NativeHlsPlayer
- New param: `Duration? resumePosition`
- In `_open()`, after `player.open()`, call `await _player.seek(resumePosition)` if provided
- Add `Future<void> seek(Duration position)` — delegates to `_player.seek()`
- Add `Duration? get position` — returns `_player.state.position` (live value)
- The `WatchScreen` will poll position periodically via a `Timer.periodic` and save it

#### TwitchEmbedPlayer
- New param: `Duration? resumePosition`
- New JS bridge function `NiceTvSeek(seconds)` — calls `player.seek(seconds, ...)` on the Twitch Player
- Add `Future<void> seek(Duration position)` — calls JS `NiceTvSeek(position.inSeconds)`
- Add `Future<Duration?> getCurrentPosition()` — via a `NiceTvGetCurrentTime` JS function
- The HTML template needs:
  - `window.NiceTvSeek = function(seconds) { player.seek(seconds, 'seconds'); }`
  - `window.NiceTvGetCurrentTime = function() { post({type: 'position', position: player.getCurrentTime()}); }`

**Twitch.Player API verification:** The Twitch.Player JS API supports `seek(seconds, Twitch.Player.Origin)` and `getCurrentTime()`. The `seek` method takes a float (seconds) and returns void.

### Save Logic in WatchScreen
- Only for VODs (`widget.vodId != null`)
- `Timer.periodic(10 seconds)` → read `_nativeKey.currentState.position` or call JS → `vodProgressStore.savePosition(vodId, position)`
- On dispose / pause: save the final position
- On init: read saved position and pass as `resumePosition` to the player

### Edge Cases
- VOD shorter than saved position → clamp to duration
- Live streams → skip entirely
- Position saved near the end → don't auto-resume (last 10% of vod)

---

## 2. Playback Speed Control (suggestion 2.1)

### Goal

Allow the user to change playback speed (0.25x–2x) for both players.

### Affected Files

- `lib/features/watch/presentation/watch_screen.dart` — speed selector UI
- `lib/features/watch/presentation/native_hls_player.dart` — `setPlaybackSpeed()`
- `lib/features/watch/presentation/twitch_embed_player.dart` — `setPlaybackSpeed()` via JS
- `assets/twitch_player.html` — `NiceTvSetRate(rate)` JS function
- `lib/features/settings/data/settings_controller.dart` — optional: persist default speed

### Design

#### NativeHlsPlayer
- Add `Future<void> setPlaybackSpeed(double speed)` → `_player.setRate(speed)`
- `Player.setRate(double)` is available in `media_kit` 1.2.6

#### TwitchEmbedPlayer
- Add `Future<void> setPlaybackSpeed(double speed)` → `runJavaScript('NiceTvSetRate($speed)')`
- HTML template: `window.NiceTvSetRate = function(rate) { try { player.setPlaybackRate(rate); } catch(e) {} }`
- **Note:** The Twitch.Player iframe API does not officially support `setPlaybackRate`. This is an experimental/best-effort approach — it may silently fail on the embed player. If it doesn't work, the UI should still be shown but disabled for embed mode.

#### WatchScreen UI
- Add to the existing `PopupMenuButton<String>` (Quality) or a new `PopupMenuButton<double>` for speed
- Options: 0.25x, 0.5x, 0.75x, Normal (1.0x), 1.25x, 1.5x, 1.75x, 2x
- Show current speed with icon `Icons.speed_outlined`
- Persist via `settingsControllerProvider.setPlaybackSpeed()`

**Decision:** Include in settings persistence for consistency. Add `playbackSpeed` (double, default 1.0) to `AppSettings`, `SettingsStorage`, and `SettingsController`.

---

## 3. Share Stream / Clip (suggestion 5.2)

### Goal

Add a share button to the WatchScreen that opens the platform share sheet with a Twitch URL.

### Affected Files

- `pubspec.yaml` — add `share_plus: ^5.0.0`
- `lib/features/watch/presentation/watch_screen.dart` — share button + URL builder
- `lib/features/home/presentation/home_screen.dart` — optional: share button on StreamCard
- `lib/features/home/presentation/autoplay_feed.dart` — optional: share button in autoplay overlay

### Design

#### URL Builder
```dart
String twitchShareUrl({String? channelLogin, String? vodId, String? clipId}) {
  if (clipId != null && clipId.isNotEmpty) {
    return 'https://clips.twitch.tv/$clipId';
  }
  if (vodId != null && vodId.isNotEmpty) {
    return 'https://www.twitch.tv/videos/$vodId';
  }
  if (channelLogin != null && channelLogin.isNotEmpty) {
    return 'https://www.twitch.tv/$channelLogin';
  }
  return '';
}
```

Place in `lib/features/home/data/twitch_stream.dart` or a new `lib/features/share/data/share_url.dart`.

#### WatchScreen
- Add `IconButton` (`Icons.share_outlined`) in AppBar actions
- Tooltip: 'Share'
- On press: `Share.share(twitchShareUrl(...))`

#### Dependencies
- Add `share_plus: ^5.0.0` to `pubspec.yaml`

---

## Implementation Order

1. Resume VOD position (highest priority) — `vod_progress_store.dart`, player changes, WatchScreen
2. Playback speed control — player changes, HTML bridge, settings, WatchScreen UI
3. Share button — `pubspec.yaml`, URL helper, WatchScreen AppBar

## Testing

- **Resume position:** Unit test `VodProgressStore` read/write round-trip
- **Playback speed:** Verify `NativeHlsPlayer.setPlaybackSpeed` calls `Player.setRate`
- **Share:** Widget test verifying share button calls expected URL builder (mock `Share.share`)
- Run `flutter analyze` + `flutter test` after each feature

## Cross-check Against suggestions.md

| Suggestion | Status |
|---|---|
| 3.1 Sort & Filter | Already implemented (`_DiscoveryFilterBar`, `applyDiscoveryFilters`) |
| 3.2 Mature Content Toggle | Already implemented (`discoveryHideMature`) |
| 3.3 Language Filter | Already implemented (`discoveryLanguage`) |
| 3.4 Watch History | Already implemented (`history_controller.dart`, `history_screen.dart`) |
| 4.1 Follow/Unfollow | Already implemented (`follow_controller.dart`) |
| 2.1 Playback Speed | **Planned** — see above |
| 2.3 Resume VOD | **Planned** — see above |
| 5.2 Share Stream/Clip | **Planned** — see above |
