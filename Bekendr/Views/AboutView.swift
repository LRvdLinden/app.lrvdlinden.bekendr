import SwiftUI

/// Over Bekendr: wat de app doet, de bronnen en de disclaimer.
struct AboutView: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    BekendrMark(size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bekendr").font(.title3.weight(.heavy))
                        Text("Versie \(FeedbackClient.appVersion)").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                Text("Bekendr laat je de officiële bekendmakingen zien die over jouw buurt gaan: vergunningen, verkeersbesluiten, kap, evenementen en ruimtelijke plannen. Zonder account en zonder eigen server: de app haalt de gegevens zelf op bij de openbare bronnen van de overheid.")
                    .font(.subheadline)
            }

            Section("Bronnen") {
                Link(destination: URL(string: "https://www.officielebekendmakingen.nl")!) {
                    LabeledContent("Bekendmakingen", value: "KOOP, officielebekendmakingen.nl")
                }
                Link(destination: URL(string: "https://www.pdok.nl")!) {
                    LabeledContent("Adressen en gebieden", value: "PDOK")
                }
                Link(destination: URL(string: "https://open-meteo.com")!) {
                    LabeledContent("Weer", value: "Open-Meteo (CC BY 4.0)")
                }
                LabeledContent("Kaart", value: "Apple Kaarten")
            }

            Section("Disclaimer") {
                Text("Bekendr is geen app van de overheid en is niet verbonden aan een gemeente, provincie, waterschap of het Rijk. De app toont openbare gegevens zoals de bronnen die aanleveren. Een bekendmaking kan op de verkeerde plek staan, in een andere categorie vallen of ontbreken. Alleen de officiële publicatie is geldig; daar staat ook hoe en tot wanneer je een zienswijze of bezwaar kunt indienen. Aan de inhoud van Bekendr kun je geen rechten ontlenen.")
                    .font(.subheadline)
            }

            Section {
                Link(destination: AppConfig.privacyURL) { Label("Privacyverklaring", systemImage: "hand.raised") }
                Link(destination: AppConfig.supportURL) { Label("Support en contact", systemImage: "questionmark.circle") }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Over Bekendr")
        .inlineTitle()
    }
}
