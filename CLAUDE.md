# Stookwijzer – werkafspraken

- Elke wijziging aan de app direct committen en pushen naar `main`; de repo is altijd de actuele versie.
- Versie staat in `Stookwijzer.xcodeproj/project.pbxproj` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) en moet voor app en widget gelijk zijn. Huidig: 1.0.0 (build 6).
- Na elke nieuwe build ook een zip van het Xcode-project in de chat aanleveren (`Stookwijzer-1.0.0-build<N>.zip`, zonder .git).
- Taal van UI en documentatie: Nederlands.
- Pushmeldingen: app → Cloudflare Worker (`server/worker`) → GitHub Action (`scripts/send-push.mjs`) → APNs. Secrets: APN_TEAM_ID, APN_KEY_ID, APN_P8_CERT, CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID. Worker wordt gedeployd door `deploy-worker.yml`; URL en admin-token worden afgeleid.
