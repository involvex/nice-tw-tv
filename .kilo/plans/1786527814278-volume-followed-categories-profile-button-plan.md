# Plan: Volume persistence, followed categories, profile button

## Context

Three requests: (1) fix volume resetting to mute on every swipe in autoplay feed, (2) list followed categories on the Following tab, (3) add a profile-view button on the WatchScreen.

## 1. Bug Fix: Volume resets to mute when swiping autoplay feed

### Root Cause

`lib/features/home/presentation/autoplay_feed.dart:55-86` — `_AutoplayPage` creates a fresh `TwitchEmbedPlayer` whenever `active` flips to `true`. Each `TwitchEmbedPlayer` (in `lib/features/watch/presentation/twitch_embed_player.dart:62-160`) creates a new `WebViewController` in `initState()` and loads `assets/twitch_player.html`. That HTML sets `muted: false` but mobile WebViews block autoplay-with-sound, so the Twitch player starts muted. No volume/muted state is persisted across player instances. The `NativeHlsPlayer` has no volume control at all.

### Fix

1. **New shared provider** — `lib/features/watch/presentation/` or a new state file:
   - `final playerVolumeProvider = StateProvider<double>((ref) => 0.7)` — persisted in `SettingsStorage`/`SharedPreferences` via a new `SettingsController` setter or a dedicated `StateProvider` with `ref.listen` persistence.
   - `final playerMutedProvider = StateProvider<bool>((ref) => false)` — also persisted.

2. **HTML bridge** — `assets/twitch_player.html`:
   - Add `window.NiceTvSetMuted(muted)` JS function that calls `player.setMuted(muted)`.
   - Add `window.NiceTvSetVolume(volume)` JS function that calls `player.setVolume(volume)`.
   - Keep `muted: false` in the Twitch.Player options so initial state is unmuted.

3. **`TwitchEmbedPlayer`** — accept `initialMuted` and `initialVolume` constructor params. After `READY` event fires (in the JS bridge `post()` callback), call `runJavaScript('NiceTvSetMuted($muted)')` and `NiceTvSetVolume($volume)`. Add `setMuted(bool)` and `setVolume(double)` public methods that invoke the JS bridge.

4. **`NativeHlsPlayer`** — same: accept `initialMuted`/`initialVolume`, call `_player.setVolume()` and `_player.setMuted()` in `_open()` after the media is loaded.

5. **`AutoplayFeed` / `_AutoplayPage`** — pass `ref.watch(playerVolumeProvider)` and `ref.watch(playerMutedProvider)` to `TwitchEmbedPlayer`. When the JS bridge emits events (or on user interaction), update the shared providers.

6. **`WatchScreen`** — pass the same shared providers to whichever player it renders (embed or native), so volume persists when navigating from the autoplay feed into the full watch screen and back.

### Alternative considered

Keep `TwitchEmbedPlayer` mounted for adjacent pages (pre-warm) instead of destroying on `active: false`. This avoids recreating the WebView but is more complex and doesn't solve the initial-mute-on-first-play issue. The shared-state approach is simpler and covers all cases.

## 2. Feature: List followed categories on the Following tab

### API constraints

The Twitch Helix API has **no direct "followed categories" endpoint**. `GET /helix/channels/followed` returns followed *channels* (users), not categories. We derive followed categories from the channels the user follows.

### Approach

1. **Extend `TwitchStream`** (`lib/features/home/data/twitch_stream.dart`):
   - Add `gameId` field (Helix returns `game_id` on `/helix/streams` and `/helix/streams/followed`).

2. **Add `getGamesByIds`** to `HelixRepository` (`lib/features/home/data/helix_repository.dart`):
   - Calls `GET /helix/games?id=1,2,3...` (max 50 IDs per request).
   - Returns `List<TwitchCategory>` (reuses existing `TwitchCategory.fromJson` model which already has `boxArtUrl`).

3. **Add `getFollowedCategories`** to `HelixRepository`:
   - Calls `GET /helix/channels/followed?user_id=<userId>&first=100` to get followed broadcaster IDs (reuses `getFollowedChannels`).
   - Calls `GET /helix/channels?broadcaster_id=X&broadcaster_id=Y...` to get each channel's `game_id` and `game_name`.
   - Dedupes game IDs.
   - Calls `GET /helix/games?id=...` to resolve full category details (box art).
   - Returns `List<TwitchCategory>`.
   - Requires OAuth scope `user:read:follows` (already present in `AppEnv.oauthScopes`).

4. **New provider** — `lib/features/home/data/helix_repository.dart` or a new file:
   - `followedCategoriesProvider = FutureProvider.autoDispose<List<TwitchCategory>>((ref) async { ... })`
   - Reads auth state; if not logged in, returns `[]`.
   - Calls `helixRepository.getFollowedCategories(userId)`.
   - Can be refreshed via `ref.refresh(followedCategoriesProvider.future)`.

5. **Update `FollowingScreen`** (`lib/features/home/presentation/following_screen.dart`):
   - Add a horizontal scrollable category chips strip at the top (similar to `_CategoryChips` in `home_screen.dart`), placed above the stream `ListView`.
   - Each chip shows the category box-art avatar + name.
   - Tapping a chip navigates to `/category/{category.id}?name={category.name}` (existing route).
   - Show `All` chip to filter the stream list by "all followed channels" (default view).
   - Loading state: show `LinearProgressIndicator` in the header area.
   - Error state: silently skip (or show a small retry).

6. **OAuth scope check** — verify the `user:read:follows` scope covers `/helix/channels/followed` and `/helix/channels`. The existing scope list already includes `user:read:follows`.

### Data flow

```
FollowingScreen (UI)
  ↓ ref.watch
followedCategoriesProvider (FutureProvider)
  ↓ calls
HelixRepository.getFollowedCategories()
  ↓ 1. GET /helix/channels/followed?user_id=X
      2. GET /helix/channels?broadcaster_id=... 
      3. GET /helix/games?id=...
  ↓ returns
List<TwitchCategory>
```

## 3. Feature: Button to view streamer's profile (bio) on WatchScreen

### Implementation

The profile route `/profile/:login?userId=...` already exists in `app_router.dart:73-81` and is already used from `StreamCard` and `_AutoplayPage`. We just need to add a button in `WatchScreen`.

1. **Add `IconButton`** in `WatchScreen.build()` — in the AppBar `actions` list (`lib/features/watch/presentation/watch_screen.dart:372-447`):
   - Place it after the follow button (or before it).
   - Tooltip: 'View profile'.
   - Icon: `Icons.person_outline` (or `Icons.info_outline`).
   - `onPressed`: `context.push('/profile/${widget.channelLogin}?userId=${widget.broadcasterId}')`.
   - Only show when `widget.broadcasterId != null` (the profile route works with login alone too, but userId gives better data).
   - If `broadcasterId` is null, still allow navigation via login only: `/profile/${widget.channelLogin}`.

2. **No new route needed** — the existing `/profile/:login` route handles it.

## Open Questions

None — all three tasks have clear, self-contained implementations using existing patterns (Riverpod providers, Helix API, go_router routes).

## Testing

- **Volume fix**: verify on device that swiping between streams preserves volume setting. No unit test needed (WebView-dependent).
- **Followed categories**: unit test for `HelixRepository.getFollowedCategories` with a mock Dio; widget test for `FollowingScreen` category chip rendering with a mocked provider.
- **Profile button**: widget test verifying the IconButton navigates to `/profile/:login`.
