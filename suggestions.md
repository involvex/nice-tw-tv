# Nice TV — Feature Suggestions

A curated set of features that can be implemented on top of the current Nice TV codebase. Each item includes rationale, affected areas, and a rough priority.

---

## 0. Recently Implemented

> **Note:** These features already exist in the codebase and do not require implementation.

- **Continue Watching Shelf** — `lib/features/home/presentation/continue_watching_shelf.dart` + `lib/features/vod/data/continue_watching_provider.dart`; rendered on the home screen.
- **Mini player** — floating PiP-style overlay via `lib/features/watch/presentation/mini_player.dart` + `lib/features/watch/data/player_overlay_controller.dart`.
- **Similar streams shelf** — `lib/features/profile/presentation/similar_streams_shelf.dart` on channel profiles.
- **Category browse & category autoplay feeds** — `category_browse_screen.dart`, `category_autoplay_feed.dart`, routes `/category/:id` and `/category/:id/autoplay`.
- **Search history** — recent queries via `lib/features/search/data/search_history_controller.dart`.
- **Chat reply system** — long-press a message to reply in `lib/features/chat/presentation/chat_panel.dart`.
- **Emote search & picker** — emote search field and picker in `lib/features/chat/presentation/chat_panel.dart`.
- **Chat UX & moderation** — user cards, in-room search, block list, timeout/ban, room-state badges, persisted history.
- **Chat personalization** — timestamps, font size/family, link masking, per-channel accent/quality overrides.
- **Channel enrichment** — panels, schedule, clips shelf, share, offline followed, VOD chapters, history search, theater mode.
- **Settings personalization** — high contrast, quiet hours, per-channel notification mutes, settings export/import.
- **Channel moments & handoff (1.5)** — USERNOTICE system rows, mention highlight, live/VOD end handoff + auto-advance.

---

## 1. Chat UX & Moderation

### 1.1 User Cards (tap username)
**Status:** Already implemented.

### 1.2 Chat Search
**Status:** Already implemented.

### 1.3 Chat Timestamps Toggle
**Status:** Already implemented.

### 1.4 Block / Ignore Users
**Status:** Already implemented.

### 1.5 Chat Link Protection / Spoiler Toggle
**Status:** Already implemented.

### 1.6 Chat Polls & Predictions Display
**Priority:** Low
**Rationale:** Viewer IRC does not deliver polls/predictions cleanly; needs PubSub or extra scopes.
**Affected files:**
- `lib/features/chat/data/irc_message.dart`
- `lib/features/chat/presentation/chat_panel.dart`

### 1.7 Auto-Translate Chat
**Priority:** Low
**Rationale:** Integrate with a translation API (e.g., LibreTranslate) to auto-translate non-English chat messages.
**Affected files:**
- `lib/features/chat/presentation/chat_panel.dart`
- New: `lib/features/chat/data/translation_service.dart`

### 1.8 Channel Moments (USERNOTICE)
**Status:** Already implemented in 1.5 — raids, subs, announcements as system chat rows.

### 1.9 Mention Highlight
**Status:** Already implemented in 1.5.

---

## 2. Video Player Enhancements

> **Note:** Playback speed control (0.25x–2x), quality selection, mute/unmute, volume, and VOD resume are already implemented.

### 2.1 Theater Mode
**Status:** Already implemented.

### 2.2 Volume Boost / Audio Normalization
**Priority:** Low
**Rationale:** Some streams are too quiet. A software volume boost (up to 2x) via the native player would help.
**Affected files:**
- `lib/features/watch/presentation/native_hls_player.dart`
- `lib/features/watch/presentation/watch_screen.dart`

### 2.3 Stream Delay Indicator
**Priority:** Low
**Rationale:** Estimate and display current stream delay (Twitch low-latency vs. normal).
**Affected files:**
- `lib/features/watch/presentation/watch_screen.dart`

### 2.4 Playback Handoff / Auto-Advance
**Status:** Already implemented in 1.5.

---

## 3. Stream Discovery & Organization

> **Note:** Sort/filter controls (viewer count, recently started, alphabetical, language, mature), language filter, and watch history are already implemented.

### 3.1 Mature Content Toggle
**Priority:** High
**Rationale:** Respect Twitch's mature flag and add a global setting to hide mature streams.
**Status:** Already implemented in `settings_controller.dart` (`discoveryHideMature`) and applied in `helix_repository.dart` (`applyDiscoveryFilters`).

### 3.2 Watch History
**Priority:** High
**Rationale:** Keep a local history of watched streams and VODs so users can jump back in.
**Status:** Already implemented via `lib/features/history/data/history_store.dart`, `history_controller.dart`, `history_screen.dart`, and route `/history`.

### 3.3 Followed Channels Not Live Quick Filter
**Status:** Already implemented (`offline_channels_section.dart`).

### 3.4 Continue Watching Shelf
**Status:** Already implemented via `continue_watching_shelf.dart`.

---

## 4. Channel Profile Enrichment

> **Note:** Follow/unfollow is already implemented via `FollowController` and exposed in the profile and watch screens.

### 4.1 Channel Panels & About Section
**Status:** Already implemented.

### 4.2 Raid / Host Info
**Priority:** Low
**Rationale:** Raid moments already appear in chat via USERNOTICE. Separate host/raid history APIs remain limited on Helix.

### 4.3 Share Profile
**Status:** Already implemented.

---

## 5. VOD & Clip Improvements

> **Note:** Share stream/clip is already implemented in the watch screen via `SharePlus`.

### 5.1 VOD Chapters
**Status:** Already implemented.

### 5.2 Clip Download
**Priority:** Low
**Rationale:** Let users download clips locally using the download manager.
**Affected files:**
- New provider/screen or action in `lib/features/watch/presentation/watch_screen.dart`
- Add dependency: `flutter_downloader` or `dio` download

---

## 6. Notifications & Live Alerts

> **Note:** Live alerts via EventSub, polling fallback, notifications inbox, mark all read, clear all, and push notifications are already implemented.

### 6.1 Per-Channel Notification Toggles
**Status:** Already implemented (`muted_channels_store.dart`).

### 6.2 Notification Sound & Vibration Customization
**Priority:** Low
**Rationale:** Customize sound, vibration, and LED for live alerts using `flutter_local_notifications`.
**Affected files:**
- `lib/features/notifications/data/local_push_service.dart`
- `lib/features/settings/presentation/settings_screen.dart`

### 6.3 DND / Quiet Hours
**Status:** Already implemented.

---

## 7. iOS & Platform Parity

### 7.1 iOS Picture-in-Picture
**Priority:** High
**Rationale:** `PipService` is Android-only. Implement iOS PiP via `AVPictureInPictureController` on the native side and expose it through the existing platform channel or a new one.
**Affected files:**
- `lib/features/watch/data/pip_service.dart`
- `ios/Runner/` (Swift/ObjC platform channel implementation)

### 7.2 Lock Screen / Now Playing Integration
**Priority:** Medium
**Rationale:** Show stream title and playback controls on the lock screen / notification shade using `media_kit`'s audio session features. Most useful once native HLS is the default player.
**Affected files:**
- `lib/features/watch/presentation/native_hls_player.dart`

### 7.3 3D Touch / Haptic Feedback
**Priority:** Low
**Rationale:** Add haptic feedback on chat message long-press, stream card taps, etc.

---

## 8. Personalization & Settings

### 8.1 Export / Import Settings
**Status:** Already implemented.

### 8.2 Chat Font Size & Font Family
**Status:** Already implemented.

### 8.3 Auto-Play Next Stream
**Status:** Already implemented in 1.5 (`autoAdvanceNext` + playback handoff).

---

## 9. Accessibility & Quality of Life

### 9.1 Screen Reader Labels
**Priority:** Medium
**Rationale:** Add `Semantics` widgets to stream cards, chat messages, and buttons to improve TalkBack / VoiceOver support.
**Affected files:**
- `lib/features/home/presentation/home_screen.dart`
- `lib/features/chat/presentation/chat_panel.dart`
- `lib/features/watch/presentation/watch_screen.dart`

### 9.2 High Contrast Theme
**Status:** Already implemented.

### 9.3 Swipe Actions on Stream Cards
**Priority:** Low
**Rationale:** Swipe left on a stream card to quick-watch, swipe right to open profile, etc.
**Affected files:**
- `lib/features/home/presentation/home_screen.dart`

---

## 10. Advanced / Experimental

### 10.1 Multi-Stream (Side-by-Side)
**Priority:** Low
**Rationale:** Watch up to 4 streams at once using multiple `TwitchEmbedPlayer` or native players. Heavy on memory and bandwidth.
**Affected files:**
- New: `lib/features/watch/presentation/multi_stream_screen.dart`
- `lib/core/routing/app_router.dart`

---

## 11. New Opportunities

### 11.1 Moderation Actions (Timeout / Ban)
**Status:** Already implemented via user card actions.

### 11.2 Chat Room State Indicators
**Status:** Already implemented.

### 11.3 Chat History Persistence
**Status:** Already implemented (`chat_history_store.dart`).

### 11.4 Stream Schedule on Channel Profile
**Status:** Already implemented.

### 11.5 Clips Tab on Channel Profile
**Status:** Already implemented (`channel_clips_shelf.dart`).

### 11.6 Per-Channel Player & Theme Overrides
**Status:** Already implemented (`accentArgb`, `qualityOverride` on layout profiles).

### 11.7 Account Switcher / Multi-Account
**Priority:** Medium
**Rationale:** Let users store multiple Twitch OAuth tokens and switch between accounts without logging out. Persist token list in `flutter_secure_storage`.
**Affected files:**
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/settings/presentation/settings_screen.dart`

### 11.8 Autoplay Next VOD in Series
**Status:** Already implemented in 1.5 playback handoff.

### 11.9 Search Within Watch History
**Status:** Already implemented.

---

## Implementation Notes

- Follow the existing **feature-based architecture** (`data/` + `presentation/`).
- Use **Riverpod** for state and **GoRouter** for navigation.
- Add new settings to `AppSettings` and persist them via `SettingsStorage`.
- Prefer **small, focused PRs** — most items above can be delivered independently.
- Keep `.env` and secrets out of version control (already enforced).
- When adding new dependencies, update `pubspec.yaml` and document the choice in this file.

---

*Last updated: 2026-11-22*
