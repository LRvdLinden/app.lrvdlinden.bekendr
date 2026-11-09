# App Store-content Bekendr 1.0.0

Alles voor de App Store-pagina van Bekendr (iPhone, iPad en Mac).

## Talen
- **Afbeeldingen: alleen nl-NL.** Bekendr is alleen Nederlandstalig; Engelse screenshots zouden de app verkeerd voorstellen. App Store Connect toont de NL-screenshots ook op de Engelse pagina.
- **Teksten: nl-NL en en-US** (`metadata/`). De Engelse beschrijving zegt dat de app in het Nederlands is.
- **Review-notities: Engels** (`metadata/review_information/notes.txt`), met een Nederlandse kopie.

## Inhoud
| Map | Wat |
| --- | --- |
| `screenshots/nl-NL/iphone-6.3/` | 6 screenshots 1206×2622 |
| `screenshots/nl-NL/iphone-6.1/` | 6 screenshots 1179×2556 |
| `screenshots/nl-NL/ipad-13/` | 4 screenshots 2064×2752 |
| `screenshots/nl-NL/ipad-12.9/` | 4 screenshots 2048×2732 |
| `screenshots/nl-NL/mac/` | 3 screenshots, elk in 2880×1800, 2560×1600, 1440×900 en 1280×800 (upload één maat) |
| `marketing/nl-NL/` | header 5244×2950 en 3840×1646; zoekresultaat 5244×2950, 3840×2560 en 1920×1280 |
| `metadata/` | naam, ondertitel, promotietekst, beschrijving, trefwoorden, Wat is nieuw, URL's, categorie, copyright, privacy, review-informatie |
| `app-info.md` | algemene info, leeftijd, privacylabel, toegankelijkheid |

Volgorde van de screenshots: buurt, meldingen, kaart, details, buurten samenvoegen, melding en widget.

De schermen zijn **nagebouwd** uit de SwiftUI-code (zelfde teksten, kleuren en indeling) met neutrale voorbeeldgegevens, omdat er hier geen Xcode-simulator is. De kaart is een eigen tekening in plaats van Apple Kaarten. Vervang ze desgewenst door simulatoropnames.

## Uploaden (checklist)
1. App aanmaken in App Store Connect: bundle-id `app.lrvdlinden.bekendr`, SKU `app.lrvdlinden.bekendr`, primaire taal Nederlands.
2. Engels (VS) als extra lokalisatie toevoegen voor de Engelse teksten.
3. Screenshots per toestel uploaden (iPhone 6,3"/6,1", iPad 13"/12,9", Mac).
4. Teksten uit `metadata/nl-NL` en `metadata/en-US` plakken.
5. Categorie, leeftijd, privacylabel en toegankelijkheid volgens `app-info.md`.
6. App Review Information: notities uit `notes.txt`, geen inlog; telefoon en e-mail zelf invullen.
7. Productpagina: header- en zoekresultaatbeelden uit `marketing/nl-NL`.

Open punten: Apple ID, telefoon en e-mail voor App Review.
