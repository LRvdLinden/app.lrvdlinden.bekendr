#!/usr/bin/env node
/**
 * Stookwijzer push-runner (draait elk uur in GitHub Actions, zonder npm-dependencies).
 *
 * 1. Haalt aanmeldingen op bij de Cloudflare Worker
 * 2. Vraagt per unieke locatie het RIVM-stookadvies op
 * 3. Vergelijkt met de laatst gemelde code en stuurt bij een wijziging een APNs-melding
 * 4. Schrijft de nieuwe status terug en ruimt ongeldige tokens op
 *
 * Omgevingsvariabelen
 *   APN_TEAM_ID, APN_KEY_ID, APN_P8_CERT   APNs token-auth (inhoud van het .p8-bestand)
 *   APN_TOPIC                              bundle-id, standaard nl.lrvdlinden.stookwijzer
 *   WORKER_URL, WORKER_ADMIN_TOKEN         Cloudflare Worker
 *   DRY_RUN=1                              niets versturen of terugschrijven, alleen loggen
 *   TEST_TOKEN, TEST_ENV                   stuur één testmelding naar dit token (sandbox|production) en stop
 */

import crypto from "node:crypto";
import http2 from "node:http2";

const env = process.env;
const TOPIC = env.APN_TOPIC || "nl.lrvdlinden.stookwijzer";
const DRY_RUN = env.DRY_RUN === "1" || env.DRY_RUN === "true";

const CODES = {
  0: { title: "Code geel", headline: "Stoken kan", body: "De omstandigheden zijn weer redelijk. Stook je, let dan op je buren." },
  1: { title: "Code oranje", headline: "Liever niet stoken", body: "Weinig wind of matige luchtkwaliteit: rook blijft langer hangen." },
  2: { title: "Code rood", headline: "Niet stoken", body: "Rook verspreidt zich slecht. In sommige gemeenten kun je nu een boete krijgen." },
};

// ---------------------------------------------------------------- APNs

function loadKey() {
  let pem = (env.APN_P8_CERT || "").trim();
  if (!pem) throw new Error("APN_P8_CERT ontbreekt");
  pem = pem.replace(/\\n/g, "\n");
  if (!pem.includes("BEGIN PRIVATE KEY")) {
    // base64 van het hele bestand, of alleen de sleutelregel
    const decoded = Buffer.from(pem, "base64").toString("utf8");
    pem = decoded.includes("BEGIN PRIVATE KEY")
      ? decoded
      : `-----BEGIN PRIVATE KEY-----\n${pem.replace(/\s+/g, "").match(/.{1,64}/g).join("\n")}\n-----END PRIVATE KEY-----\n`;
  }
  return crypto.createPrivateKey(pem);
}

function b64url(input) {
  return Buffer.from(input).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function makeJWT() {
  if (!env.APN_TEAM_ID || !env.APN_KEY_ID) throw new Error("APN_TEAM_ID of APN_KEY_ID ontbreekt");
  const header = b64url(JSON.stringify({ alg: "ES256", kid: env.APN_KEY_ID.trim() }));
  const claims = b64url(JSON.stringify({ iss: env.APN_TEAM_ID.trim(), iat: Math.floor(Date.now() / 1000) }));
  const signature = crypto.sign("sha256", Buffer.from(`${header}.${claims}`), {
    key: loadKey(),
    dsaEncoding: "ieee-p1363",
  });
  return `${header}.${claims}.${b64url(signature)}`;
}

const sessions = {};
function apnsSession(environment) {
  const host = environment === "sandbox" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
  if (!sessions[host] || sessions[host].closed || sessions[host].destroyed) {
    sessions[host] = http2.connect(host);
    sessions[host].on("error", () => {});
  }
  return sessions[host];
}

let jwt;
function sendAPNs(token, environment, payload, collapseId) {
  jwt ??= makeJWT();
  return new Promise((resolve) => {
    const req = apnsSession(environment).request({
      ":method": "POST",
      ":path": `/3/device/${token}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": TOPIC,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": String(Math.floor(Date.now() / 1000) + 6 * 3600),
      ...(collapseId ? { "apns-collapse-id": collapseId.slice(0, 64) } : {}),
      "content-type": "application/json",
    });
    let status = 0;
    let data = "";
    req.on("response", (h) => (status = h[":status"]));
    req.on("data", (c) => (data += c));
    req.on("end", () => {
      let reason;
      try { reason = data ? JSON.parse(data).reason : undefined; } catch {}
      resolve({ status, reason });
    });
    req.on("error", (e) => resolve({ status: 0, reason: e.message }));
    req.setTimeout(15000, () => { req.close(); resolve({ status: 0, reason: "timeout" }); });
    req.end(JSON.stringify(payload));
  });
}

// ---------------------------------------------------------------- RIVM Stookwijzer

function toRD(lat, lon) {
  const Rp = [0, 1, 2, 0, 1, 3, 1, 0, 2], Rq = [1, 1, 1, 3, 0, 1, 3, 2, 3];
  const Rpq = [190094.945, -11832.228, -114.221, -32.391, -0.705, -2.34, -0.608, -0.008, 0.148];
  const Sp = [1, 0, 2, 1, 3, 0, 2, 1, 0, 1], Sq = [0, 2, 0, 2, 0, 1, 2, 1, 4, 4];
  const Spq = [309056.544, 3638.893, 73.077, -157.984, 59.788, 0.433, -6.439, -0.032, 0.092, -0.054];
  const df = 0.36 * (lat - 52.1551744), dl = 0.36 * (lon - 5.38720621);
  let x = 155000, y = 463000;
  for (let i = 0; i < Rpq.length; i++) x += Rpq[i] * df ** Rp[i] * dl ** Rq[i];
  for (let i = 0; i < Spq.length; i++) y += Spq[i] * df ** Sp[i] * dl ** Sq[i];
  return { x, y };
}

/** "dd-mm-yyyy HH:MM" in Nederlandse tijd → Date */
function parseRuntime(s) {
  const m = /^(\d{2})-(\d{2})-(\d{4}) (\d{2}):(\d{2})$/.exec(String(s || "").trim());
  if (!m) return null;
  const [, d, mo, y, h, mi] = m.map(Number);
  // Offset van Europe/Amsterdam op dat moment bepalen
  const guess = Date.UTC(y, mo - 1, d, h, mi);
  const tz = new Intl.DateTimeFormat("en-US", { timeZone: "Europe/Amsterdam", timeZoneName: "shortOffset" })
    .formatToParts(new Date(guess)).find((p) => p.type === "timeZoneName")?.value || "GMT+1";
  const offsetH = Number((tz.match(/GMT([+-]\d+)/) || [, "+1"])[1]);
  return new Date(guess - offsetH * 3600 * 1000);
}

async function fetchAdvice(lat, lon) {
  const { x, y } = toRD(lat, lon);
  const bbox = [x, y, x + 10, y + 10].map((v) => v.toFixed(0)).join(",");
  const params = [
    "SERVICE=WMS", "VERSION=1.3.0", "REQUEST=GetFeatureInfo", "FORMAT=image/png", "TRANSPARENT=true",
    "QUERY_LAYERS=stookwijzer_v2", "LAYERS=stookwijzer_v2", "servicekey=82b124ad-834d-4c10-8bd0-ee730d5c1cc8",
    "STYLES=", "BUFFER=1", "EXCEPTIONS=INIMAGE", "info_format=application/json", "feature_count=1",
    "I=139", "J=222", "WIDTH=256", "HEIGHT=256", "CRS=EPSG:28992", `BBOX=${bbox}`,
  ].join("&");
  const res = await fetch(`https://data.rivm.nl/geo/alo/wms?${params}`, { signal: AbortSignal.timeout(20000) });
  if (!res.ok) throw new Error(`RIVM HTTP ${res.status}`);
  const props = (await res.json())?.features?.[0]?.properties;
  if (!props) throw new Error("geen data");

  const base = parseRuntime(props.model_runtime) || new Date();
  const slots = Object.keys(props)
    .map((k) => /^advies_(\d+)$/.exec(k))
    .filter(Boolean)
    .map((m) => ({ offset: Number(m[1]), code: Number(props[m[0]]) }))
    .filter((s) => s.code in CODES)
    .map((s) => ({ ...s, date: new Date(base.getTime() + s.offset * 3600 * 1000) }))
    .sort((a, b) => a.date - b.date);
  if (!slots.length) throw new Error("geen adviesvelden");

  const now = Date.now();
  const current = [...slots].reverse().find((s) => s.date.getTime() <= now) || slots[0];
  const next = slots.find((s) => s.date.getTime() > now && s.code !== current.code);
  return { code: current.code, next };
}

// ---------------------------------------------------------------- Worker

async function worker(path, init = {}) {
  const res = await fetch(`${env.WORKER_URL.replace(/\/+$/, "")}${path}`, {
    ...init,
    headers: { authorization: `Bearer ${env.WORKER_ADMIN_TOKEN}`, "content-type": "application/json", ...(init.headers || {}) },
  });
  if (!res.ok) throw new Error(`Worker ${path} HTTP ${res.status}`);
  return res.json();
}

// ---------------------------------------------------------------- Main

function shouldNotify(previous, current, sub) {
  if (previous === undefined || previous === null) return false; // eerste meting: alleen opslaan
  if (previous === current) return false;
  if (current >= sub.minCode) return true;                          // naar oranje/rood (of hoger dan drempel)
  return sub.notifyAllClear && previous >= sub.minCode;             // terug onder de drempel
}

function buildPayload(place, code, next) {
  const c = CODES[code];
  const time = (d) => d.toLocaleTimeString("nl-NL", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Amsterdam" });
  const extra = next ? ` Vanaf ${time(next.date)} ${CODES[next.code].title.toLowerCase()}.` : "";
  return {
    aps: {
      alert: { title: `${c.title} in ${place.name}`, subtitle: c.headline, body: c.body + extra },
      sound: "default",
      "thread-id": `place-${place.id}`,
      "interruption-level": code === 2 ? "time-sensitive" : "active",
    },
    placeId: place.id,
    code,
  };
}

async function sendTest() {
  const payload = {
    aps: { alert: { title: "Stookwijzer", subtitle: "Testmelding", body: "Pushmeldingen werken 🎉" }, sound: "default" },
  };
  const r = await sendAPNs(env.TEST_TOKEN.trim(), env.TEST_ENV || "sandbox", payload);
  console.log(`Testmelding: HTTP ${r.status}${r.reason ? ` (${r.reason})` : ""}`);
  if (r.status !== 200) process.exitCode = 1;
}

async function main() {
  if (env.TEST_TOKEN) return sendTest();
  if (!env.WORKER_URL || !env.WORKER_ADMIN_TOKEN) {
    console.log("Meldingsserver nog niet geconfigureerd (Cloudflare-secrets ontbreken), niets te doen");
    return;
  }

  const { subscriptions } = await worker("/subscriptions");
  console.log(`${subscriptions.length} aanmelding(en)`);

  // Unieke locaties ophalen (afgerond op 2 decimalen, zoals de app aanlevert)
  const adviceByLoc = new Map();
  for (const sub of subscriptions) for (const p of sub.places || []) adviceByLoc.set(`${p.lat},${p.lon}`, null);
  for (const loc of adviceByLoc.keys()) {
    const [lat, lon] = loc.split(",").map(Number);
    try {
      adviceByLoc.set(loc, await fetchAdvice(lat, lon));
    } catch (e) {
      console.warn(`Advies ${loc} mislukt: ${e.message}`);
    }
  }
  console.log(`${adviceByLoc.size} locatie(s) gecontroleerd`);

  const updates = [];
  const remove = [];
  let sent = 0;

  for (const sub of subscriptions) {
    const newState = {};
    let invalid = false;

    for (const place of sub.places || []) {
      const advice = adviceByLoc.get(`${place.lat},${place.lon}`);
      if (!advice) continue;
      const previous = sub.state?.[place.id];
      newState[place.id] = advice.code;

      if (!shouldNotify(previous, advice.code, sub)) continue;

      const payload = buildPayload(place, advice.code, advice.next);
      const tokenTail = sub.token.slice(-6);
      if (DRY_RUN) {
        console.log(`[dry-run] …${tokenTail} ${place.name}: ${CODES[previous]?.title} → ${CODES[advice.code].title}`);
        continue;
      }
      const r = await sendAPNs(sub.token, sub.environment, payload, `stook-${place.id}`);
      if (r.status === 200) {
        sent++;
        console.log(`Verstuurd …${tokenTail} ${place.name}: ${CODES[advice.code].title}`);
      } else if (r.status === 410 || ["BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"].includes(r.reason)) {
        console.log(`Token …${tokenTail} ongeldig (${r.reason}), verwijderen`);
        invalid = true;
        break;
      } else {
        console.warn(`APNs …${tokenTail}: HTTP ${r.status} ${r.reason || ""}`);
        delete newState[place.id]; // volgende keer opnieuw proberen
      }
    }

    if (invalid) remove.push(sub.token);
    else if (Object.keys(newState).length) updates.push({ token: sub.token, state: newState });
  }

  if (!DRY_RUN && (updates.length || remove.length)) {
    const r = await worker("/state", { method: "POST", body: JSON.stringify({ updates, remove }) });
    console.log(`Status bijgewerkt: ${r.updated}, verwijderd: ${r.removed}`);
  }
  console.log(`${sent} melding(en) verstuurd`);
}

main()
  .catch((e) => {
    console.error(e.message);
    process.exitCode = 1;
  })
  .finally(() => Object.values(sessions).forEach((s) => s.close()));
