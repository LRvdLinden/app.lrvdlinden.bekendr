# Bekendr – werkafspraken

- Elke wijziging aan de app direct committen en pushen naar `main`; de repo is altijd de actuele versie.
- Versie: Apple in `Bekendr.xcodeproj/project.pbxproj` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`), gelijk voor app, widget en deel-extensie; Android in `android/app/build.gradle.kts` (`versionName`, `versionCode`). Huidig: 1.0.0 (build 1).
- Het Xcode-project wordt gemaakt met een script; bij nieuwe targets of instellingen het pbxproj zorgvuldig bijwerken. Mappen zijn gesynchroniseerd (Xcode 16).
- Na elke push de builds controleren: **Apple-build** (iOS + macOS) en **Android-APK** (APK in Releases).
- Apple niet in de simulator testen; Léon test zelf.
- Taal van UI en documentatie: alleen Nederlands.
- Geen eigen server. Data: KOOP SRU (`repository.overheid.nl/sru`) en PDOK Locatieserver.
- Android-APK altijd met dezelfde sleutel: `android/signing/bekendr.jks.enc`, ontgrendeld met repo-secret `APN_P8_CERT` (nooit verwijderen of wijzigen). Nooit een nieuwe sleutel maken.
- Android is alleen lokaal (geen sync). Apple synchroniseert via iCloud (SwiftData + CloudKit, container `iCloud.app.lrvdlinden.bekendr`).
- Standaarden uit de skill `lrvdlinden-app-defaults`: MoreAppsCard, AppInfoFooter, review-prompt, privacy manifest, Weergave-keuze.
