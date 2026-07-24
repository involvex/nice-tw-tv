# Nice TV

Modern Android-first Twitch client built with Flutter. Clean-room implementation inspired by the architecture of third-party clients like Frosty — not a fork.

## Features (MVP)

- Twitch frontpage: popular live streams + following feed with infinite scroll
- Live watch via Twitch WebView embed + chat/video split in landscape
- IRC chat with Twitch, BetterTTV, FrankerFaceZ, and 7TV emotes
- Emote autocomplete and picker
- Light / dark / system themes with accent customization
- Chat density and default stream quality settings
- Twitch OAuth (redirect `https://twitch.tv/login`)

## Setup

1. Copy `.env.example` to `.env` and set your Twitch app credentials:

```env
CLIENT_ID=your_twitch_client_id
SECRET=your_twitch_client_secret
```

2. In the [Twitch Developer Console](https://dev.twitch.tv/console), set OAuth Redirect URL to:

```text
https://twitch.tv/login
```

3. Run:

```bash
flutter pub get
flutter run
```

## Notes

- `SECRET` is used for anonymous Helix browse via client-credentials. Prefer a backend proxy before shipping production release builds.
- Do not commit `.env`.
- Video uses the official Twitch embed player for MVP stability.

## Verify

```bash
dart format .
flutter analyze
flutter test
```
