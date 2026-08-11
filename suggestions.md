# Nice TV — Feature Suggestions

A curated set of features that can be implemented on top of the current Nice TV codebase. Each item includes rationale, affected areas, and a rough priority.

---

## 1. Chat UX & Moderation

### 1.1 User Cards (tap username)
**Priority:** Medium
**Rationale:** Long-pressing a username currently only starts a reply. Tapping a username should open a small bottom sheet with the user's profile picture, description, and a shortcut to visit their profile.
**Affected files:**
- `lib/features/chat/presentation/chat_panel.dart` (`ChatMessageTile`)
- `lib/features/profile/presentation/channel_profile_screen.dart`

### 1.2 Chat Search
**Priority:** Medium
**Rationale:** Chat moves fast. Allow searching within the current room's message history (client-side filter over the loaded 400 messages) to find specific messages or links.
**Affected files:**
- `lib/features/chat/presentation/chat_panel.dart`
- `lib/features/chat/data/chat_client.dart`

### 1.3 Chat Timestamps Toggle
**Priority:** Low
**Rationale:** Some users prefer timestamps on chat messages. Add a per-streamer or global toggle to show/hide message timestamps.
**Affected files:**
- `lib/features/chat/presentation/chat_panel.dart`
- `lib/features/settings/data/settings_controller.dart`
- `lib/features/settings/data/layout_profile.dart`

### 1.4 Block / Ignore Users
**Priority:** Medium
**Rationale:** Let logged-in users block chat messages from specific users. Store the blocked list in `SharedPreferences` and filter messages client-side.
**Affected files:**
- `lib/features/chat/presentation/chat_panel.dart`
- `lib/features/settings/data/settings_controller.dart`
- `lib/features/settings/presentation/settings_screen.dart`

### 1.5 Chat Link Protection / Spoiler Toggle
**Priority:** Low
**Rationale:** Optionally mask or blur URLs in chat to avoid accidental spoilers or unwanted redirects.
**Affected files:**
- `lib/features/chat/data/irc_message.dart`
- `lib/features/chat/presentation/chat_panel.dart`

---

## 2. Video Player Enhancements

### 2.1 Playback Speed Control
**Priority:** Medium
**Rationale:** Twitch embed and native HLS players both support playback rate changes. Expose a 0.25x–2x speed selector in the watch screen.
**Affected files:**
- `lib/features/watch/presentation/watch_screen.dart`
- `lib/features/watch/presentation/twitch_embed_player.dart`
- `lib/features/watch/presentation/native_hls_player.dart`

### 2.2 Theater Mode
**Priority:** Low
**Rationale:** Immersive full-width player with chat overlaid (or hidden). Useful on phones in landscape and on tablets.
**Affected files:**
- `lib/features/watch/presentation/watch_screen.dart`
- `lib/features/settings/data/layout_profile.dart`

### 2.3 Resume VOD from Last Position
**Priority:** High
**Rationale:** Store the last watched position per VOD in `SharedPreferences` and seek to it when opening the player.
**Affected files:**
- `lib/features/watch/presentation/watch_screen.dart`
- `lib/features/watch/presentation/twitch_embed_player.dart`
- `lib/features/watch/presentation/native_hls_player.dart`
- New: `lib/features/vod/data/vod_progress_store.dart`

### 2.4 Volume Boost / Audio Normalization
**Priority:** Low
**Rationale:** Some streams are too quiet. A software volume boost (up to 2x) via the native player would help.
**Affected files:**
- `lib/features/watch/presentation/native_hls_player.dart`
- `lib/features/watch/presentation/watch_screen.dart`

---

## 3. Stream Discovery & Organization

### 3.1 Sort & Filter Controls
**Priority:** High
**Rationale:** Currently the home feed shows top streams. Add sorting (viewer count, recently started, alphabetically) and filtering (language, mature content).
**Affected files:**
- `lib/features/home/data/helix_repository.dart`
- `lib/features/home/presentation/home_screen.dart`
- `lib/features/home/data/twitch_stream.dart`

### 3.2 Mature Content Toggle
**Priority:** High
**Rationale:** Respect Twitch's mature flag and add a global setting to hide mature streams.
**Affected files:**
- `lib/features/home/data/twitch_stream.dart`
- `lib/features/home/data/helix_repository.dart`
- `lib/features/settings/data/settings_controller.dart`
- `lib/features/settings/presentation/settings_screen.dart`

### 3.3 Language Filter
**Priority:** Medium
**Rationale:** Let users filter the browse and following feeds by language.
**Affected files:**
- `lib/features/home/data/helix_repository.dart`
- `lib/features/home/presentation/home_screen.dart`

### 3.4 Watch History
**Priority:** High
**Rationale:** Keep a local history of watched streams and VODs so users can jump back in.
**Affected files:**
- New: `lib/features/history/data/history_store.dart`
- New: `lib/features/history/presentation/history_screen.dart`
- `lib/core/routing/app_router.dart`

### 3.5 Followed Channels Not Live Quick Filter
**Priority:** Low
**Rationale:** In the Following tab, show a small section of followed channels that are currently offline, with their last stream info.
**Affected files:**
- `lib/features/home/presentation/following_screen.dart`
- `lib/features/home/data/helix_repository.dart`

---

## 4. Channel Profile Enrichment

### 4.1 Follow / Unfollow Button
**Priority:** High
**Rationale:** Currently the profile screen shows data but does not allow following/unfollowing a channel from the app. Expose the Helix `Follow`/`Unfollow` endpoints.
**Affected files:**
- `lib/features/profile/presentation/channel_profile_screen.dart`
- `lib/features/home/data/helix_repository.dart`
- `lib/features/auth/data/auth_repository.dart` (for scopes)

### 4.2 Channel Panels & About Section
**Priority:** Medium
**Rationale:** Twitch channel profiles have panels (links, rules, etc.). Fetch and render them in `ChannelProfileScreen`.
**Affected files:**
- `lib/features/profile/presentation/channel_profile_screen.dart`
- `lib/features/home/data/helix_repository.dart`
- `lib/features/home/data/twitch_models.dart`

### 4.3 Raid / Host Info
**Priority:** Low
**Rationale:** Show recent raids/hosts if the API provides it (currently limited on Helix; can be skipped if unavailable).

---

## 5. VOD & Clip Improvements

### 5.1 VOD Chapters
**Priority:** Medium
**Rationale:** Many VODs have chapters. Parse and display them when opening a VOD to allow skipping between segments.
**Affected files:**
- `lib/features/vod/data/twitch_vod.dart`
- `lib/features/watch/presentation/watch_screen.dart`

### 5.2 Share Stream / Clip
**Priority:** Medium
**Rationale:** Add a share button to the watch screen and clip view that copies the Twitch URL or uses the platform share sheet.
**Affected files:**
- `lib/features/watch/presentation/watch_screen.dart`
- Add dependency: `flutter: share_plus`

### 5.3 Clip Download
**Priority:** Low
**Rationale:** Let users download clips locally using the download manager.
**Affected files:**
- New provider/screen or action in `lib/features/watch/presentation/watch_screen.dart`
- Add dependency: `flutter_downloader` or `dio` download

---

## 6. Notifications & Live Alerts

### 6.1 Per-Channel Notification Toggles
**Priority:** Medium
**Rationale:** Let users mute notifications for specific followed channels without unfollowing them.
**Affected files:**
- `lib/features/notifications/data/notifications_inbox.dart`
- `lib/features/notifications/presentation/notifications_screen.dart`
- New: `lib/features/notifications/data/muted_channels_store.dart`

### 6.2 Notification Sound & Vibration Customization
**Priority:** Low
**Rationale:** Customize sound, vibration, and LED for live alerts using `flutter_local_notifications`.
**Affected files:**
- `lib/features/notifications/data/local_push_service.dart`
- `lib/features/settings/presentation/settings_screen.dart`

### 6.3 DND / Quiet Hours
**Priority:** Low
**Rationale:** Suppress live notifications during user-defined hours.
**Affected files:**
- `lib/features/notifications/data/notifications_inbox.dart`
- `lib/features/settings/data/settings_controller.dart`

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
**Rationale:** Show stream title and playback controls on the lock screen / notification shade using `media_kit`'s audio session features.
**Affected files:**
- `lib/features/watch/presentation/native_hls_player.dart`

### 7.3 3D Touch / Haptic Feedback
**Priority:** Low
**Rationale:** Add haptic feedback on chat message long-press, stream card taps, etc.

---

## 8. Personalization & Settings

### 8.1 Export / Import Settings
**Priority:** Medium
**Rationale:** Allow users to export their settings, layout profiles, and blocked users to a JSON file and import them on another device.
**Affected files:**
- `lib/features/settings/data/settings_controller.dart`
- `lib/features/settings/presentation/settings_screen.dart`

### 8.2 Chat Font Size & Font Family
**Priority:** Low
**Rationale:** Let users choose a different chat font size or font family beyond the current density presets.
**Affected files:**
- `lib/features/chat/presentation/chat_panel.dart`
- `lib/features/settings/data/settings_controller.dart`

### 8.3 Auto-Play Next Stream
**Priority:** Low
**Rationale:** After a stream ends, automatically open the next recommended stream (useful for the autoplay feed mode).
**Affected files:**
- `lib/features/watch/presentation/watch_screen.dart`
- `lib/features/home/presentation/autoplay_feed.dart`

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
**Priority:** Low
**Rationale:** Add a high-contrast color scheme for visually impaired users.
**Affected files:**
- `lib/core/theme/nice_tv_theme.dart`
- `lib/features/settings/data/settings_controller.dart`

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

### 10.2 Chat Polls & Predictions Display
**Priority:** Low
**Rationale:** Parse and render Twitch channel poll/prediction messages from IRC tags. Requires additional IRC tag parsing.
**Affected files:**
- `lib/features/chat/data/irc_message.dart`
- `lib/features/chat/presentation/chat_panel.dart`

### 10.3 Auto-Translate Chat
**Priority:** Low
**Rationale:** Integrate with a translation API (e.g., LibreTranslate) to auto-translate non-English chat messages.
**Affected files:**
- `lib/features/chat/presentation/chat_panel.dart`
- New: `lib/features/chat/data/translation_service.dart`

### 10.4 Stream Delay Indicator
**Priority:** Low
**Rationale:** Estimate and display current stream delay (Twitch low-latency vs. normal).
**Affected files:**
- `lib/features/watch/presentation/watch_screen.dart`

---

## Implementation Notes

- Follow the existing **feature-based architecture** (`data/` + `presentation/`).
- Use **Riverpod** for state and **GoRouter** for navigation.
- Add new settings to `AppSettings` and persist them via `SettingsStorage`.
- Prefer **small, focused PRs** — most items above can be delivered independently.
- Keep `.env` and secrets out of version control (already enforced).
- When adding new dependencies, update `pubspec.yaml` and document the choice in this file.

---

*Last updated: 2026-08-11*
