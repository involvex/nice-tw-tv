# Nice TV

Modern Android-first Twitch client built with Flutter. Clean-room implementation inspired by the architecture of third-party clients like Frosty — not a fork.

## Features (MVP → v1.3)

- Twitch frontpage: popular live streams + following feed with infinite scroll
- Card feed ↔ fullscreen autoplay swipe toggle
- Search (live channels + categories), channel profiles
- VOD shelf from popular channels’ recent archives
- Live/VOD watch via Twitch embed JS bridge **or** experimental native HLS (quality variants + auto-fallback to embed)
- Android Picture-in-Picture
- Per-streamer layout profiles (chat placement, density, split ratio, player)
- IRC chat with reconnect, badges, replies (long-press), and cheer highlighting
- BTTV / FFZ / 7TV emotes + live 7TV set updates
- Emote autocomplete and tabbed emote picker with search
- Live alerts: poll + EventSub WebSocket + local OS notifications (optional remote FCM via worker)
- Light / dark / system themes with accent customization
- Twitch OAuth (redirect `https://twitch.tv/login`)

## Setup

1. Copy `.env.example` to `.env` and set credentials:

```env
CLIENT_ID=your_twitch_client_id
TOKEN_PROXY_URL=https://nice-tv-token-proxy.involvex.workers.dev
```

For local-only debug without the proxy, you may set `SECRET` instead of `TOKEN_PROXY_URL`.

See [`workers/token-proxy`](workers/token-proxy) (deployed) or [`netlify/functions/twitch-app-token.mts`](netlify/functions/twitch-app-token.mts).

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

- Prefer `TOKEN_PROXY_URL` so `SECRET` never ships in release APKs. The proxy is deployed at `https://nice-tv-token-proxy.involvex.workers.dev`.
- Do not commit `.env`.
- Video defaults to the official Twitch embed player for stability; native HLS is experimental but supports named quality variants from the Usher master playlist.
- Live push: EventSub WebSocket + local OS notifications while the app runs. Optional remote FCM via the worker (`FCM_SERVER_KEY` + KV) for killed-state delivery.

## Verify / release checklist

```bash
dart format .
flutter analyze
flutter test
```

Smoke on device: sign in, Following tab, watch + chat send, notifications inbox after a followed channel goes live, native HLS failure falls back to embed.
