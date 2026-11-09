# Bekendr – App-informatie voor App Store Connect

Versie 1.0.0 (build 1) · bundle-id `app.lrvdlinden.bekendr` · platforms iPhone, iPad en Mac (macOS 14+, eigen Mac-app) · iOS/iPadOS 17+

## Algemene informatie (General Information)
| Veld | Waarde |
| --- | --- |
| Bundle ID | `app.lrvdlinden.bekendr` (widget `app.lrvdlinden.bekendr.widget`, deel-extensie `app.lrvdlinden.bekendr.share`) |
| SKU | `app.lrvdlinden.bekendr` |
| Apple ID | TODO: Léon vult in na het aanmaken van de app in App Store Connect |
| Primary Language | Dutch |
| App-talen | Nederlands (alleen) |
| Primary Category | News – officiële bekendmakingen van de overheid, nieuws over je eigen buurt |
| Secondary Category | Utilities – praktisch hulpmiddel om je omgeving te volgen |
| Content Rights | Ja, de app toont inhoud van derden: officiële publicaties via KOOP (officielebekendmakingen.nl, open data, vrij te hergebruiken) en adresgegevens van PDOK (open data). Bron staat in de app. |
| License Agreement | Apple Standard EULA |
| Copyright | © 2026 Léon van der Linden |
| Support URL | https://bekendr.lrvdlinden.app/support/ |
| Marketing URL | https://bekendr.lrvdlinden.app/ |
| Privacy Policy URL | https://bekendr.lrvdlinden.app/privacy/ |

## Leeftijdsclassificatie (Age Rating)
Alle vragen **None / No**: geen geweld, seks, grof taalgebruik, drugs, gokken, horror, medische informatie; geen onbeperkte webtoegang (alleen links naar officielebekendmakingen.nl die in Safari openen); geen door gebruikers gemaakte inhoud; geen chat. Uitkomst: **4+**.

## App Privacy (privacylabel)
Geen tracking (geen ATT), niets gekoppeld aan de identiteit van de gebruiker. Aan te vinken als **Data Collected – Not Linked to You**, doel **App Functionality**:
| Gegevenstype | Waarom |
| --- | --- |
| User Content → Other User Content | feedback op een bekendmaking (gekozen reden en toelichting), alleen als de gebruiker die zelf verstuurt |
| Identifiers → Device ID | willekeurig nummer van de app-installatie bij feedback, alleen als hash bewaard, tegen misbruik |
| Location → Coarse Location | coördinaten van een gekozen locatie, afgerond op ~100 m, naar Open-Meteo voor het weer op Vandaag |

- Geen account, geen analytics, geen crash-SDK, geen advertenties.
- Locaties en gelezen/bewaard staan alleen op het toestel en in de eigen iCloud van de gebruiker (CloudKit, privédatabase): de ontwikkelaar kan er niet bij.
- Voor het ophalen stuurt de app coördinaten of een gebiedsnaam rechtstreeks naar de openbare API's van KOOP en PDOK; die worden niet door de ontwikkelaar ontvangen of bewaard.
- Huidige locatie alleen op verzoek ("Gebruik huidige locatie"), alleen om een adres in te vullen; niet bewaard als locatiegeschiedenis.
- Meldingen zijn lokaal; er gaat geen pushtoken naar een server.
- `PrivacyInfo.xcprivacy` van de app: dezelfde drie gegevenstypen (niet gekoppeld, geen tracking, App Functionality); widget en deel-extensie verzamelen niets.
- SDK's van derden: geen.

## Toegankelijkheid (Accessibility Nutrition Labels)
Per apparaat (iPhone, iPad, Mac), alleen wat in de code is gecontroleerd:
| Kenmerk | Status |
| --- | --- |
| Dark Interface | Geclaimd: alle kleuren hebben een lichte en donkere variant; keuze Automatisch/Licht/Donker in Instellingen |
| Larger Text | Geclaimd: systeemlettertypen met tekststijlen (Dynamic Type) |
| Differentiate Without Color Alone | Geclaimd: categorieën hebben altijd een icoon en een naam naast de kleur |
| VoiceOver | Geclaimd na een korte test door Léon: rijen, tegels en knoppen hebben toegankelijkheidslabels |
| Voice Control | Niet geclaimd (niet getest) |
| Sufficient Contrast | Niet geclaimd (niet gemeten) |
| Reduced Motion | Niet geclaimd |
| Captions / Audio Descriptions | Niet van toepassing (geen video of audio) |

## App Review Information
- Notes: `metadata/review_information/notes.txt` (Engels, voor App Store Connect); Nederlandse kopie in `notes-nl.txt`.
- Sign-in required: **No** (geen account).
- Contact: Léon van der Linden; telefoon en e-mail: TODO (zelf invullen in App Store Connect).
