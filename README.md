# Bekendr

**Versie 1.0.0 (build 1)** · bundle-id `app.lrvdlinden.bekendr`

Officiële bekendmakingen rond je adres, wijk of gemeente: vergunningen, verkeersbesluiten, kap, evenementen en ruimtelijke plannen. De gegevens komen rechtstreeks van KOOP ([officielebekendmakingen.nl](https://www.officielebekendmakingen.nl)) en PDOK; er is geen eigen server en geen account.

Gebaseerd op het idee van de Homey-app *Bekendmakingen NL* en de werking van OmgevingsAlert, met een eigen ontwerp.

## Wat de app doet
- Meerdere locaties: een adres met een straal (100 m – 2 km) of een hele woonplaats, wijk, buurt of gemeente.
- Per locatie kies je de categorieën: Vergunningen, Verkeer, Bomen en kap, Evenementen, Ruimtelijke plannen, Regels en overig.
- **Jouw buurt**: hoeveel er nieuw is, vandaag en de afgelopen 7 dagen, met tegels per categorie.
- **Meldingen**: als lijst of op de kaart (rondjes in de categoriekleur met een wit icoon), gelezen/ongelezen, bewaren en prullenbak (30 dagen).
- **Bekendmaking**: instantie, datum, afstand, kaartje, samenvatting en de link naar de officiële publicatie. "Locatie klopt niet?" opent een melding in GitHub.
- Lokale meldingen bij iets nieuws, met stille uren. Op iOS via Achtergrond vernieuwen, op Android elk uur via WorkManager.
- Vergrendeling met Face ID / Touch ID (Android: vingerafdruk of gezicht).
- Alleen Nederlands.

## Platforms
| | Apple (iPhone, iPad, Mac) | Android |
|---|---|---|
| Sync | iCloud (SwiftData + CloudKit): locaties, gelezen, bewaard, prullenbak | Alles lokaal op het toestel |
| Extra | Widget (klein, middel, groot, vergrendelscherm), deel-extensie voor adressen | Delen van een adres naar de app |
| Kaart | MapKit | OpenStreetMap (osmdroid) |
| Levering | Xcode → App Store Connect | Losse APK in [Releases](../../releases) |

## Apple: bouwen
1. Open `Bekendr.xcodeproj` (Xcode 16 of nieuwer). Team `EU3UY476T6` en automatische ondertekening staan al ingesteld.
2. Zet bij het App-ID de capabilities aan: iCloud (container `iCloud.app.lrvdlinden.bekendr`), Push Notifications (voor de iCloud-sync), App Groups (`group.app.lrvdlinden.bekendr`). Xcode doet dit meestal zelf bij de eerste build op een toestel.
3. Kies een iPhone, iPad of *My Mac* en druk op Run.

Mappen: `Bekendr/` (app), `Shared/` (app + widget + deel-extensie), `BekendrWidget/`, `BekendrShare/`. Het zijn gesynchroniseerde mappen: nieuwe bestanden verschijnen vanzelf in Xcode.

## Android: bouwen
- Elke push naar `android/` bouwt via **Android-APK** een ondertekende release-APK en zet die in Releases.
- Lokaal: open `android/` in Android Studio, of `./gradlew assembleRelease`.
- Elke APK wordt met dezelfde vaste sleutel ondertekend, zodat updates over de vorige versie heen installeren. De sleutel staat versleuteld in `android/signing/bekendr.jks.enc` en wordt in de workflow ontgrendeld met de repo-secret `APN_P8_CERT`. **Verwijder of wijzig die secret niet**, anders kan de sleutel niet meer worden geopend. Het buildnummer (`versionCode`) is het runnummer van de workflow.

## CI
- **Apple-build**: bouwt de app voor iOS en macOS zonder ondertekening (controle of alles compileert).
- **Android-APK**: bouwt en publiceert de APK.

## Gegevensbronnen
- KOOP SRU 2.0 (`repository.overheid.nl/sru`), collectie *officielepublicaties*, zoeken op locatiepunt en afgeleid gebied (straal of rechthoek, grote gebieden in vakken van max. ± 230 km²).
- PDOK Locatieserver v3.1 voor adressen, gebieden en hun grenzen.

---
Meer apps: [lrvdlinden.app](https://lrvdlinden.app)
