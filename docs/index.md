---
title: Nice TV
nav_order: 1
---

# Nice TV

Modern Android-first Twitch client built with Flutter. Clean-room implementation inspired by the architecture of third-party clients like Frosty — not a fork.

![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-blue)
![Dart](https://img.shields.io/badge/Dart-latest-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## Quick Links

- [Getting Started](getting-started.md)
- [Architecture](architecture.md)
- [Contributing](contributing.md)
- [Build & Release](build-and-release.md)
- [Troubleshooting](troubleshooting.md)
- [Changelog](changelog.md)

## Features

- Twitch frontpage: popular live streams + following feed with infinite scroll
- Card feed ↔ fullscreen autoplay swipe toggle
- Search (live channels + categories), channel profiles
- VOD shelf from popular channels' recent archives
- Live/VOD watch via Twitch embed JS bridge or experimental native HLS
- Android Picture-in-Picture
- Per-streamer layout profiles (chat placement, density, split ratio, player)
- IRC chat with reconnect, badges, replies, and cheer highlighting
- BTTV / FFZ / 7TV emotes + live 7TV set updates
- Emote autocomplete and tabbed emote picker with search
- Live alerts: poll + EventSub WebSocket + local OS notifications
- Light / dark / system themes with accent customization
- Twitch OAuth (redirect `https://twitch.tv/login`)
