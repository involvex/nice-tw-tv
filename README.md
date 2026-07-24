# Nice TV

Modern Android-first Twitch client built with Flutter. Clean-room implementation inspired by the architecture of third-party clients like Frosty — not a fork.

## Features (MVP + v1.1)

- Twitch frontpage: popular live streams + following feed with infinite scroll
- VOD shelf from popular channels’ recent archives
- Live/VOD watch via Twitch embed JS bridge **or** experimental native HLS
- Android Picture-in-Picture
- Per-streamer layout profiles (chat placement, density, split ratio, player)
- IRC chat with Twitch, BetterTTV, FrankerFaceZ, and 7TV emotes
- Live 7TV emote-set websocket updates
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
