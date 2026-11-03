import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        FlameLogo().frame(width: 48, height: 60)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Over de Stookwijzer")
                                .font(.system(.title2, design: .rounded).bold())
                            Text("Advies van het RIVM, per locatie")
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.bottom, 4)

                    section(icon: "questionmark.circle.fill",
                            title: "Hoe komt de code tot stand?",
                            text: "Het RIVM berekent het advies uit de windsnelheid en de luchtkwaliteit (LKI). Bij weinig wind blijft rook laag hangen; bij matige of slechte luchtkwaliteit komt houtrook daar nog bovenop. Hoe ongunstiger, hoe hoger de code.")

                    section(icon: "calendar.badge.clock",
                            title: "Verwachting",
                            text: "Het advies wordt per blok van 6 uur gegeven. Blokken die nog kunnen veranderen zijn gemarkeerd als 'voorlopig'. Trek omlaag om te verversen.")

                    section(icon: "building.columns.fill",
                            title: "Regels in je gemeente",
                            text: "Steeds meer gemeenten stellen regels voor houtstook. Bij code oranje of rood kan in sommige gemeenten een stookverbod gelden of een boete volgen. Check de regels van jouw gemeente.")

                    section(icon: "leaf.fill",
                            title: "Slimmer stoken",
                            text: "Stook alleen droog, onbehandeld hout, zorg voor voldoende luchttoevoer en laat je schoorsteen jaarlijks vegen. Dat scheelt rook, geur en fijnstof.")

                    Link(destination: URL(string: "https://www.atlasleefomgeving.nl/stookwijzer")!) {
                        Label("Stookwijzer op Atlas Leefomgeving", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 6)

                    Text("Deze app is niet van het RIVM. Het advies komt rechtstreeks uit de open data van de RIVM Stookwijzer.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(MoreAppsText.current.section.uppercased())
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                            .padding(.leading, 4)
                        MoreAppsCard()
                    }
                    .padding(.top, 12)
                }
                .padding(22)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }

    private func section(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.ember)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                Text(text).font(.subheadline).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 20)
    }
}
