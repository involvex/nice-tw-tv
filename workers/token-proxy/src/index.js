/// Minimal Cloudflare Worker that exchanges Twitch client credentials for an
/// app access token so the Flutter app never ships `SECRET`.
///
/// Deploy:
///   cd workers/token-proxy
///   npx wrangler secret put TWITCH_CLIENT_ID
///   npx wrangler secret put TWITCH_CLIENT_SECRET
///   npx wrangler deploy
///
/// Then set in the app `.env`:
///   CLIENT_ID=<same public client id>
///   TOKEN_PROXY_URL=https://<worker>.workers.dev
///
/// Leave `SECRET` empty in production builds.

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (request.method !== 'GET' && request.method !== 'POST') {
      return json({ error: 'method_not_allowed' }, 405);
    }

    const clientId = env.TWITCH_CLIENT_ID;
    const clientSecret = env.TWITCH_CLIENT_SECRET;
    if (!clientId || !clientSecret) {
      return json({ error: 'misconfigured' }, 500);
    }

    const body = new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'client_credentials',
    });

    const upstream = await fetch('https://id.twitch.tv/oauth2/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });

    const payload = await upstream.text();
    return new Response(payload, {
      status: upstream.status,
      headers: {
        ...corsHeaders(),
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
    });
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
  });
}
