# Nice TV

Modern Android-first Twitch client built with Flutter. Clean-room implementation inspired by the architecture of third-party clients like Frosty — not a fork.

## Features (MVP + v1.1 + v1.2)

- Twitch frontpage: popular live streams + following feed with infinite scroll
- Card feed ↔ fullscreen autoplay swipe toggle
- Search (live channels + categories), channel profiles
- VOD shelf from popular channels’ recent archives
- Live/VOD watch via Twitch embed JS bridge **or** experimental native HLS (auto-fallback to embed on failure)
- Android Picture-in-Picture
- Per-streamer layout profiles (chat placement, density, split ratio, player)
- IRC chat with reconnect, connection status, Twitch badges
- BTTV / FFZ / 7TV emotes + live 7TV set updates
- Emote autocomplete and tabbed emote picker with search
- In-app live notifications for followed channels (poll + local inbox)
- Light / dark / system themes with accent customization
- Twitch OAuth (redirect `https://twitch.tv/login`)

## Setup

1. Copy `.env.example` to `.env` and set credentials:

```env
CLIENT_ID=your_twitch_client_id
SECRET=your_twitch_client_secret
```

For production / release APKs, prefer a token proxy and leave `SECRET` empty:

```env
CLIENT_ID=your_twitch_client_id
TOKEN_PROXY_URL=https://your-worker.workers.dev
```

See [`workers/token-proxy`](workers/token-proxy) (Cloudflare) or [`netlify/functions/twitch-app-token.mts`](netlify/functions/twitch-app-token.mts).

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

- `SECRET` is used for anonymous Helix browse via client-credentials when no proxy is configured. Do not ship it in production release builds — use `TOKEN_PROXY_URL`.
- Do not commit `.env`.
- Video defaults to the official Twitch embed player for stability; native HLS is experimental.

## Verify / release checklist

```bash
dart format .
flutter analyze
flutter test
```

Smoke on device: sign in, Following tab, watch + chat send, notifications inbox after a followed channel goes live, native HLS failure falls back to embed.
