# Stookwijzer (iOS & iPadOS)

**Versie 1.0.0 (build 3)** · bundle-id `nl.lrvdlinden.stookwijzer`

SwiftUI-app met het RIVM-stookadvies voor je locatie: geanimeerd splashscreen, verwachting per 6 uur,
wind en luchtkwaliteit, meerdere plaatsen, iPad-layout met zijbalk, widgets en pushmeldingen bij een codewissel.

## App bouwen
1. Open `Stookwijzer.xcodeproj` (Xcode 16 of nieuwer)
2. Kies je Team bij *Signing & Capabilities* voor beide targets (Stookwijzer en StookwijzerWidgetExtension)
3. Kies een iPhone/iPad of simulator (iOS 17+) en druk op Run

De mappen zijn gesynchroniseerde groepen: nieuwe bestanden in Finder verschijnen vanzelf in Xcode.
De App Group `group.nl.lrvdlinden.stookwijzer` deelt de gekozen plaats met de widget.

## Pushmeldingen

```
iPhone ──(token + plaatsen)──▶ Cloudflare Worker (KV)
                                      ▲
GitHub Action (elk uur) ──────────────┘  leest aanmeldingen, checkt RIVM,
        │                                 schrijft laatst gemelde code terug
        └──▶ APNs ──▶ iPhone              alleen bij een codewissel
```

- Melding bij **code oranje en rood** of **alleen rood** (instelbaar in de app via het belletje).
- Optioneel een melding als het weer **code geel** wordt.
- Code rood komt binnen als *time-sensitive*; tikken op de melding opent die plaats.
- Locaties worden afgerond op ~1 km naar de server gestuurd.

### 1. Cloudflare Worker (eenmalig)
```bash
cd server/worker
npx wrangler login
npx wrangler kv namespace create SUBSCRIPTIONS   # id invullen in wrangler.toml
npx wrangler secret put ADMIN_TOKEN              # lange willekeurige string, bv. `openssl rand -hex 32`
npx wrangler secret put APP_KEY                  # optioneel
npx wrangler deploy
```
Zet daarna de Worker-URL in `Stookwijzer/Services/PushManager.swift` → `PushConfig.serverURL` en, als je APP_KEY gebruikt, dezelfde waarde in `appKey`.

### 2. GitHub-secrets
| Secret | Waarde |
|---|---|
| `APN_TEAM_ID` | je Apple Team ID |
| `APN_KEY_ID` | Key ID van de APNs-sleutel |
| `APN_P8_CERT` | volledige inhoud van het `.p8`-bestand (base64 mag ook) |
| `WORKER_URL` | bv. `https://stookwijzer-push.<subdomein>.workers.dev` |
| `WORKER_ADMIN_TOKEN` | dezelfde waarde als `ADMIN_TOKEN` in de Worker |

### 3. Testen
- *Actions → Stookwijzer pushmeldingen → Run workflow*:
  - `dry_run` aan: laat zien wat er verstuurd zou worden.
  - `test_token` invullen (device-token uit de Xcode-console of de Worker) voor één testmelding.
    Builds vanuit Xcode gebruiken `sandbox`, TestFlight en App Store `production`.
- De eerste run slaat alleen de huidige code op; meldingen komen bij de volgende wissel.

## Structuur
- `Stookwijzer/` – app (splash, schermen, locatie, plaatsen, meldingen)
- `Shared/` – model, RIVM-API, RD-coördinaten, thema en logo (ook gebruikt door de widget)
- `StookwijzerWidget/` – widgets voor begin- en lockscreen
- `server/worker/` – Cloudflare Worker voor device-tokens
- `scripts/send-push.mjs` – controle + APNs-verzending (Node 20, geen dependencies)
- `.github/workflows/stookwijzer-push.yml` – draait het script elk uur

## Databron
RIVM Atlas Leefomgeving, WMS GetFeatureInfo op laag `stookwijzer_v2` (EPSG:28992).
De `servicekey` is de publieke sleutel van Atlas Leefomgeving (ook gebruikt door Home Assistant).
Vraag voor publicatie in de App Store bij het RIVM na of je die mag gebruiken.
