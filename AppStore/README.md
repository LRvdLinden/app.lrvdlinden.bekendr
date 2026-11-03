# App Store-materiaal – Stookwijzer 1.0.0

Alles voor App Store Connect, in **nl-NL** (primair) en **en-US**. Gegenereerd met `tools/appstore/gen.js`.

## Inhoud
- `app-info.md` – algemene info, categorie, content rights, leeftijd, app-privacy, toegankelijkheid, reviewnotities
- `metadata/` – teksten per taal (fastlane-deliver-indeling) + `privacy/` privacybeleid NL/EN
- `screenshots/<taal>/`
  - `iphone-6.9/` 1320×2868 · `iphone-6.3/` 1206×2622 · `iphone-6.1/` 1179×2556 (6 stuks)
  - `ipad-13/` 2752×2064 · `ipad-12.9/` 2732×2048 (3 stuks, liggend)
- `marketing/<taal>/` – header 5244×2950 en 3840×1646, search 5244×2950, 3840×2560 en 1920×1280
- `icon/` – App Store-icoon 1024×1024

Alle PNG's zijn RGB zonder alfakanaal. De schermen in de mockups zijn **nagebouwd** vanuit de SwiftUI-code; vervang ze door simulatoropnames zodra die er zijn. De app is Nederlandstalig, daarom staan in de Engelse screenshots Engelse koppen boven Nederlandse schermen.

## Uploadchecklist
1. App aanmaken in App Store Connect met bundle-ID `nl.lrvdlinden.stookwijzer` en SKU `nl.lrvdlinden.stookwijzer`
2. Per taal (Nederlands en Engels) de teksten uit `metadata/<taal>/` invullen
3. Screenshots uploaden: iPhone 6,9″ en iPad 13″ (de rest schaalt Apple automatisch; 6,3″/6,1″/12,9″ zijn optioneel)
4. App-privacy invullen volgens `app-info.md`
5. **Privacybeleid online zetten** en de URL invullen (staat nog op TODO)
6. Leeftijdsclassificatie, categorie en content rights volgens `app-info.md`
7. Build 7 kiezen, reviewnotities plakken en indienen
