# Nice TV token proxy (Cloudflare Worker)

Deployed URL (involvex account):

```text
https://nice-tv-token-proxy.involvex.workers.dev
```

Keeps the Twitch client secret off-device. The Flutter app calls this Worker to
obtain a Helix **app** access token (client credentials). Optional FCM fan-out
lives at `/devices` + `/eventsub` when `FCM_SERVER_KEY` and a `DEVICES` KV
binding are configured.

## Deploy / update

```bash
cd workers/token-proxy
echo YOUR_CLIENT_ID | npx wrangler secret put TWITCH_CLIENT_ID
echo YOUR_CLIENT_SECRET | npx wrangler secret put TWITCH_CLIENT_SECRET
# optional:
# echo YOUR_FCM_KEY | npx wrangler secret put FCM_SERVER_KEY
npx wrangler deploy
```

## App `.env` (release)

```env
CLIENT_ID=your_public_client_id
TOKEN_PROXY_URL=https://nice-tv-token-proxy.involvex.workers.dev
```

Leave `SECRET` unset for release builds.
