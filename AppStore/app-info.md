# Stookwijzer – App-informatie (App Store Connect)

## Algemene informatie (General Information)
| Veld | Waarde |
|---|---|
| Bundle ID | nl.lrvdlinden.stookwijzer (widget: nl.lrvdlinden.stookwijzer.widget) |
| SKU | nl.lrvdlinden.stookwijzer |
| Apple ID | TODO – staat in App Store Connect na het aanmaken van de app |
| Versie / build | 1.0.0 (7) |
| Primaire taal | Dutch (nl-NL); tweede taal English (en-US) |
| Platforms | iPhone en iPad (geen Mac, Watch of Apple TV) |
| Primaire categorie | **Weather** – het advies is gebaseerd op wind, weersverwachting en luchtkwaliteit |
| Secundaire categorie | **Lifestyle** – gaat over houtstook thuis en overlast voor de buurt |
| License Agreement | Apple Standard EULA |
| Copyright | © 2026 Léon van der Linden |

## Content Rights
Ja, de app toont inhoud van derden: het stookadvies, wind en luchtkwaliteitsindex komen uit de **open data van de RIVM Stookwijzer (Atlas Leefomgeving)**. RIVM-open data is vrij herbruikbaar met bronvermelding; de app vermeldt de bron in het hoofdscherm en het informatiescherm en zegt dat hij niet van het RIVM is. Let op: de gebruikte `servicekey` is de publieke sleutel van Atlas Leefomgeving – vraag het RIVM bij twijfel om bevestiging of een eigen sleutel.
Antwoord in ASC: *"Yes, it contains, shows, or accesses third-party content, and I have the necessary rights."*

## Leeftijdsclassificatie (Age Rating)
Alle vragen **None / No**: geen geweld, seks, grof taalgebruik, drugs, gokken, horror, medische informatie, onbeperkte webtoegang, gebruikersinhoud of berichten tussen gebruikers. Resultaat: **4+**.

## App-privacy (nutrition label)
Gegevens worden verzameld: **Ja**

| Datatype | Gekoppeld aan gebruiker | Tracking | Doel |
|---|---|---|---|
| Location → **Coarse Location** | Nee | Nee | App Functionality |

Toelichting:
- Exacte locatie blijft op het toestel; alleen coördinaten afgerond op ~1 km gaan naar de eigen meldingsserver (alleen als meldingen aan staan). De RIVM-aanvraag is een openbare kaartdienst zonder identificatie.
- Push-token van Apple: geen Device ID in de zin van Apple (geen advertentie- of apparaat-ID); niet gekoppeld aan een persoon.
- Geen SDK's van derden, geen analytics, geen crashreporting, geen advertenties, geen App Tracking Transparency nodig.
- Overeenkomstig `Stookwijzer/PrivacyInfo.xcprivacy` (CoarseLocation, UserDefaults CA92.1 + 1C8F.1, geen tracking).

## Toegankelijkheid (Accessibility Nutrition Labels) – iPhone en iPad
| Functie | Claim | Onderbouwing |
|---|---|---|
| Dark Interface | **Ja** | Alle kleuren hebben licht/donker-varianten (`Theme`, `Color(light:dark:)`) |
| Differentiate Without Color Alone | **Ja** | Elke code heeft een eigen symbool (vlam, driehoek, verbodsteken) én tekst ("Code oranje") |
| VoiceOver | Niet geclaimd | Gedeeltelijk (gecombineerde elementen, labels op knoppen); niet volledig getest |
| Voice Control | Niet geclaimd | Niet getest |
| Larger Text | Niet geclaimd | Deels Dynamic Type; enkele vaste lettergroottes |
| Sufficient Contrast | Niet geclaimd | Tekstkleuren zijn donkerder gekozen, niet formeel gemeten |
| Reduced Motion | Niet geclaimd | Splash- en pulsanimaties volgen Reduce Motion nog niet |
| Captions / Audio Descriptions | n.v.t. | Geen video of audio |

## URL's
- Support: https://lrvdlinden.app
- Marketing: https://lrvdlinden.app
- Privacybeleid: https://github.com/LRvdLinden/nl.lrvdlinden.stookwijzer/blob/main/PRIVACY.md (bron: `PRIVACY.md` in de repo, NL + EN)

## Notities voor App Review
Stookwijzer toont het openbare stookadvies (code geel/oranje/rood) van de RIVM Stookwijzer via de open data van Atlas Leefomgeving. De app is niet van het RIVM en vermeldt dat in de beschrijving en het informatiescherm. Geen account nodig. Test: sta locatie toe of zoek een plaats in Nederland (bijv. "Utrecht"); meldingen via het belletje linksboven (verstuurd bij een codewissel, dus niet direct); widgets via het beginscherm.

## Exportnaleving
Alleen standaard HTTPS → geen niet-vrijgestelde versleuteling (`ITSAppUsesNonExemptEncryption = NO`).
