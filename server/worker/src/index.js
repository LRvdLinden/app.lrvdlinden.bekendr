/**
 * Stookwijzer meldingsserver (Cloudflare Worker + KV).
 *
 * De app meldt zich hier aan met zijn APNs device-token en de plaatsen die hij volgt.
 * De GitHub Action (.github/workflows/stookwijzer-push.yml) haalt elk uur de aanmeldingen op,
 * controleert het RIVM-advies, stuurt de pushmeldingen en schrijft de laatst gemelde code terug.
 *
 * Endpoints
 *   POST   /register        (app)    aanmelden / bijwerken       header X-App-Key als APP_KEY is gezet
 *   DELETE /register        (app)    afmelden                    body { token }
 *   GET    /subscriptions   (Action) alle aanmeldingen           header Authorization: Bearer ADMIN_TOKEN
 *   POST   /state           (Action) status bijwerken/opruimen   header Authorization: Bearer ADMIN_TOKEN
 *   GET    /health                   simpele check
 *
 * Bindings / secrets
 *   SUBSCRIPTIONS  KV-namespace
 *   ADMIN_TOKEN    secret, gedeeld met de GitHub Action (WORKER_ADMIN_TOKEN)
 *   APP_KEY        optioneel secret, gelijk aan PushConfig.appKey in de app
 */

const PREFIX = "sub:";
const MAX_PLACES = 10;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    try {
      if (path === "/health") return json({ ok: true });

      if (path === "/register" && request.method === "POST") return register(request, env);
      if (path === "/register" && request.method === "DELETE") return unregister(request, env);

      if (path === "/subscriptions" && request.method === "GET") {
        requireAdmin(request, env);
        return listSubscriptions(env);
      }
      if (path === "/state" && request.method === "POST") {
        requireAdmin(request, env);
        return updateState(request, env);
      }

      return json({ error: "not_found" }, 404);
    } catch (err) {
      if (err instanceof HttpError) return json({ error: err.message }, err.status);
      return json({ error: "server_error" }, 500);
    }
  },
};

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function requireAdmin(request, env) {
  const auth = request.headers.get("authorization") || "";
  if (!env.ADMIN_TOKEN || auth !== `Bearer ${env.ADMIN_TOKEN}`) throw new HttpError(401, "unauthorized");
}

function requireAppKey(request, env) {
  if (env.APP_KEY && request.headers.get("x-app-key") !== env.APP_KEY) throw new HttpError(401, "unauthorized");
}

function validToken(token) {
  return typeof token === "string" && /^[0-9a-f]{64,200}$/i.test(token);
}

function num(v, min, max) {
  const n = Number(v);
  return Number.isFinite(n) && n >= min && n <= max ? n : null;
}

async function readJSON(request) {
  try {
    return await request.json();
  } catch {
    throw new HttpError(400, "invalid_json");
  }
}

async function register(request, env) {
  requireAppKey(request, env);
  const body = await readJSON(request);
  if (!validToken(body.token)) throw new HttpError(400, "invalid_token");

  const places = (Array.isArray(body.places) ? body.places : [])
    .slice(0, MAX_PLACES)
    .map((p) => ({
      id: String(p.id || "").slice(0, 64),
      name: String(p.name || "Onbekend").slice(0, 80),
      // Nederland ruim genomen
      lat: num(p.lat, 50.5, 54),
      lon: num(p.lon, 3, 7.5),
    }))
    .filter((p) => p.id && p.lat !== null && p.lon !== null);

  const key = PREFIX + body.token.toLowerCase();
  const existing = (await env.SUBSCRIPTIONS.get(key, "json")) || {};

  // Bewaar alleen de status van plaatsen die nog gevolgd worden
  const state = {};
  for (const p of places) if (existing.state && p.id in existing.state) state[p.id] = existing.state[p.id];

  const sub = {
    token: body.token.toLowerCase(),
    environment: body.environment === "sandbox" ? "sandbox" : "production",
    minCode: body.minCode === 2 ? 2 : 1,
    notifyAllClear: body.notifyAllClear !== false,
    places,
    state,
    appVersion: String(body.appVersion || "").slice(0, 20),
    createdAt: existing.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  await env.SUBSCRIPTIONS.put(key, JSON.stringify(sub));
  return json({ ok: true, places: places.length });
}

async function unregister(request, env) {
  requireAppKey(request, env);
  const body = await readJSON(request);
  if (!validToken(body.token)) throw new HttpError(400, "invalid_token");
  await env.SUBSCRIPTIONS.delete(PREFIX + body.token.toLowerCase());
  return json({ ok: true });
}

async function listSubscriptions(env) {
  const subs = [];
  let cursor;
  do {
    const page = await env.SUBSCRIPTIONS.list({ prefix: PREFIX, cursor });
    const values = await Promise.all(page.keys.map((k) => env.SUBSCRIPTIONS.get(k.name, "json")));
    for (const v of values) if (v) subs.push(v);
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return json({ subscriptions: subs });
}

/**
 * Body: { updates: [{ token, state: { placeId: code } }], remove: [token] }
 */
async function updateState(request, env) {
  const body = await readJSON(request);
  const updates = Array.isArray(body.updates) ? body.updates : [];
  const remove = Array.isArray(body.remove) ? body.remove : [];

  let updated = 0;
  for (const u of updates) {
    if (!validToken(u.token) || typeof u.state !== "object") continue;
    const key = PREFIX + u.token.toLowerCase();
    const sub = await env.SUBSCRIPTIONS.get(key, "json");
    if (!sub) continue;
    sub.state = { ...(sub.state || {}), ...u.state };
    sub.checkedAt = new Date().toISOString();
    await env.SUBSCRIPTIONS.put(key, JSON.stringify(sub));
    updated++;
  }

  let removed = 0;
  for (const token of remove) {
    if (!validToken(token)) continue;
    await env.SUBSCRIPTIONS.delete(PREFIX + token.toLowerCase());
    removed++;
  }

  return json({ ok: true, updated, removed });
}
