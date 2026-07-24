# Optional Netlify Function alternative to the Cloudflare Worker.
# Deploy as a site function and set TOKEN_PROXY_URL to
# https://<site>/.netlify/functions/twitch-app-token
#
# Env (Netlify UI): TWITCH_CLIENT_ID, TWITCH_CLIENT_SECRET

export default async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors() });
  }
  if (req.method !== 'GET' && req.method !== 'POST') {
    return Response.json({ error: 'method_not_allowed' }, { status: 405, headers: cors() });
  }

  const clientId = Netlify.env.get('TWITCH_CLIENT_ID');
  const clientSecret = Netlify.env.get('TWITCH_CLIENT_SECRET');
  if (!clientId || !clientSecret) {
    return Response.json({ error: 'misconfigured' }, { status: 500, headers: cors() });
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
      ...cors(),
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
};

export const config = { path: '/api/twitch-app-token' };

function cors() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}
