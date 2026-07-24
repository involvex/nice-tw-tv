# Nice TV token proxy (Cloudflare Worker)

Keeps the Twitch client secret off-device. The Flutter app calls this Worker to
obtain a Helix **app** access token (client credentials).

## Deploy

```bash
cd workers/token-proxy
npx wrangler secret put TWITCH_CLIENT_ID
npx wrangler secret put TWITCH_CLIENT_SECRET
npx wrangler deploy
```

## App `.env`

```env
CLIENT_ID=your_public_client_id
TOKEN_PROXY_URL=https://nice-tv-token-proxy.<account>.workers.dev
```

Leave `SECRET` unset for release builds.
