---
title: Changelog
nav_order: 7
---

# Changelog

All notable changes to Nice TV will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-11-22

### Added
- Channel moments in chat from IRC USERNOTICE (raids, subs, announcements, and related ritual events)
- Mention highlighting when chat messages include your Twitch login
- Playback handoff: when a live stream or VOD ends, offer similar live streams or the next archive
- Auto-advance setting to open the next handoff target automatically

## [1.4.0] - 2026-08-20

### Added
- Chat user cards, in-room search, block list, timeout/ban commands, room-state badges, and persisted history
- Chat timestamps, font size/family, and link masking
- Channel panels, schedule, clips shelf, similar streams, share, and offline followed channels
- Theater mode, VOD chapters, continue-watching shelf, mini player, playback speed, and VOD resume
- High contrast theme, quiet hours, per-channel notification mutes, and settings export/import
- Per-channel accent color and quality overrides

### Changed
- Channel profiles and discovery surfaces are richer without leaving the app

## [1.3.0] - 2026-08-12

### Added
- Category browse from frontpage with card-based infinite scroll
- Emote autocomplete and tabbed emote picker with search
- Live alerts: poll + EventSub WebSocket + local OS notifications
- Optional remote FCM via worker for killed-state delivery
- Share stream/channel via share_plus
- Adaptive launcher icons

### Changed
- Video defaults to official Twitch embed player for stability
- Native HLS remains experimental with named quality variants

### Fixed
- Various chat and emote rendering improvements

## [1.2.0] - 2026-07-15

### Added
- VOD shelf from popular channels' recent archives
- Channel profile pages with stream history
- Search for live channels and categories

### Changed
- Improved following feed infinite scroll performance

## [1.1.0] - 2026-06-20

### Added
- IRC chat with reconnect, badges, and replies
- BTTV / FFZ / 7TV emotes support
- Live 7TV emote-set websocket updates
- Light / dark / system themes with accent customization

### Fixed
- Login flow stability improvements

## [1.0.0] - 2026-05-10

### Added
- Initial release
- Twitch frontpage with popular live streams
- Following feed with infinite scroll
- Live/VOD watch via Twitch embed
- Android Picture-in-Picture
- Twitch OAuth login
