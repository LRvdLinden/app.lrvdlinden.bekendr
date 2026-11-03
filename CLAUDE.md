# Stookwijzer – werkafspraken

- Elke wijziging aan de app direct committen en pushen naar `main`; de repo is altijd de actuele versie.
- Versie staat in `Stookwijzer.xcodeproj/project.pbxproj` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) en moet voor app en widget gelijk zijn. Huidig: 1.0.0 (build 3).
- Taal van UI en documentatie: Nederlands.
- Pushmeldingen: app → Cloudflare Worker (`server/worker`) → GitHub Action (`scripts/send-push.mjs`) → APNs. Secrets: APN_TEAM_ID, APN_KEY_ID, APN_P8_CERT, WORKER_URL, WORKER_ADMIN_TOKEN.
