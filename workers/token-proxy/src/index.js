/// Nice TV edge worker: Twitch app-token proxy + optional FCM fan-out.
///
/// Secrets:
///   TWITCH_CLIENT_ID
///   TWITCH_CLIENT_SECRET
///   FCM_SERVER_KEY (optional legacy FCM server key for remote push)
///
/// KV binding `DEVICES` stores FCM registration tokens (optional).

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    if (url.pathname === '/devices' && request.method === 'POST') {
      return registerDevice(request, env);
    }

    if (url.pathname === '/eventsub' && request.method === 'POST') {
      return handleEventSub(request, env);
    }

    if (request.method !== 'GET' && request.method !== 'POST') {
      return json({ error: 'method_not_allowed' }, 405);
    }

    return issueAppToken(env);
  },
};

async function issueAppToken(env) {
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
}

async function registerDevice(request, env) {
  if (!env.DEVICES) {
    return json({ error: 'devices_kv_missing' }, 501);
  }
  const body = await request.json();
  const token = body?.token;
  const userId = body?.userId || 'anon';
  if (!token || typeof token !== 'string') {
    return json({ error: 'token_required' }, 400);
  }
  await env.DEVICES.put(`fcm:${userId}:${token.slice(-16)}`, token);
  return json({ ok: true });
}

async function handleEventSub(request, env) {
  const messageType = request.headers.get('Twitch-Eventsub-Message-Type');
  const bodyText = await request.text();
  const body = JSON.parse(bodyText);

  if (messageType === 'webhook_callback_verification') {
    return new Response(body.challenge, {
      status: 200,
      headers: { 'Content-Type': 'text/plain' },
    });
  }

  if (messageType === 'notification') {
    const type = body?.subscription?.type;
    if (type === 'stream.online' && env.FCM_SERVER_KEY && env.DEVICES) {
      const event = body.event || {};
      const title = `${event.broadcaster_user_name || 'Streamer'} is live`;
      const text = 'Tap to watch on Nice TV';
      await fanoutFcm(env, title, text, {
        login: event.broadcaster_user_login || '',
        userId: event.broadcaster_user_id || '',
      });
    }
    return json({ ok: true });
  }

  return json({ ok: true });
}

async function fanoutFcm(env, title, body, data) {
  const list = await env.DEVICES.list({ prefix: 'fcm:' });
  await Promise.all(
    list.keys.map(async (key) => {
      const token = await env.DEVICES.get(key.name);
      if (!token) return;
      await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          Authorization: `key=${env.FCM_SERVER_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: token,
          notification: { title, body },
          data,
        }),
      });
    }),
  );
}

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
