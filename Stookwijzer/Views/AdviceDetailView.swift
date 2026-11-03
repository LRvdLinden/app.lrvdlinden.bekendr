import SwiftUI

struct AdviceDetailView: View {
    @Environment(PlaceStore.self) private var places
    @Environment(AdviceViewModel.self) private var advice
    @Environment(LocationManager.self) private var location

    var onAddPlace: () -> Void
    var wide: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            if places.selected == nil {
                emptyState
            } else {
                switch advice.state {
                case .idle, .loading:
                    HeroCard(code: .yellow, nextChange: nil)
                        .redacted(reason: .placeholder)
                        .overlay { ProgressView().controlSize(.large) }
                case .failed(let message):
                    errorState(message)
                case .loaded(let data):
                    loaded(data)
                }
            }
        }
        .padding(.top, 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: stateKey)
    }

    private var stateKey: String {
        switch advice.state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .failed: return "failed"
        case .loaded(let a): return "loaded-\(a.fetchedAt.timeIntervalSince1970)-\(places.selectedID?.uuidString ?? "")"
        }
    }

    @ViewBuilder
    private func loaded(_ data: StookAdvice) -> some View {
        let code = data.currentCode()

        if wide {
            HStack(alignment: .top, spacing: 18) {
                HeroCard(code: code, nextChange: data.nextChange())
                VStack(spacing: 18) {
                    StatsGrid(advice: data, columns: 1)
                }
                .frame(width: 280)
            }
        } else {
            HeroCard(code: code, nextChange: data.nextChange())
            StatsGrid(advice: data, columns: 3)
        }

        ForecastCard(advice: data)
        CodeLegendCard(current: code)

        Text("Bron: RIVM Stookwijzer via Atlas Leefomgeving · Bijgewerkt \(NL.time(data.fetchedAt))")
            .font(.footnote)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            FlameLogo().frame(width: 72, height: 90).padding(.top, 40)
            Text("Waar wil je stoken?")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(Theme.ink)
            Text(places.locationError ?? "Deel je locatie of zoek een plaats om het stookadvies te zien.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
            VStack(spacing: 12) {
                Button {
                    Task { await places.refreshCurrentLocation(using: location) }
                } label: {
                    Label("Gebruik mijn locatie", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: onAddPlace) {
                    Label("Zoek een plaats", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: 360)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.ember)
            Text("Advies niet beschikbaar")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Theme.ink)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
            Button("Opnieuw proberen") {
                if let place = places.selected {
                    Task { await advice.load(for: place, force: true) }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Hero

struct HeroCard: View {
    let code: AdviceCode
    let nextChange: ForecastSlot?

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(code.color.opacity(0.12))
                    .frame(width: 210, height: 210)
                    .scaleEffect(pulse ? 1.04 : 0.96)
                Circle()
                    .fill(code.color.opacity(0.18))
                    .frame(width: 176, height: 176)
                Circle()
                    .fill(code.gradient)
                    .frame(width: 140, height: 140)
                    .shadow(color: code.color.opacity(0.45), radius: 22, y: 12)
                Image(systemName: code.symbol)
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.top, 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { pulse = true }
            }

            VStack(spacing: 6) {
                Text(code.title.uppercased())
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(code.textColor)
                Text(code.headline)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
            }

            Text(code.explanation)
                .font(.callout)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440)

            if let next = nextChange {
                HStack(spacing: 8) {
                    Circle().fill(next.code.color).frame(width: 10, height: 10)
                    Text("\(NL.dayTime(next.date)) wordt het \(next.code.title.lowercased())")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.background, in: Capsule())
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            LinearGradient(colors: [code.color.opacity(0.10), .clear], startPoint: .top, endPoint: .center)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stats

struct StatsGrid: View {
    let advice: StookAdvice
    let columns: Int

    var body: some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
        LazyVGrid(columns: grid, spacing: 12) {
            StatTile(symbol: "wind",
                     title: "Wind",
                     value: advice.windBft.map { "\($0) Bft" } ?? "–",
                     detail: advice.windMS.map { "\(NL.decimal($0)) m/s" })
            StatTile(symbol: "aqi.medium",
                     title: "Luchtkwaliteit",
                     value: advice.lki.map { "LKI \($0)" } ?? "–",
                     detail: advice.lki.map { AirQuality.label(for: $0) })
            StatTile(symbol: "clock",
                     title: "Model",
                     value: advice.modelRun.map(NL.time) ?? NL.time(advice.fetchedAt),
                     detail: advice.modelRun.map(NL.weekdayShort) ?? "Opgehaald")
        }
    }
}

struct StatTile: View {
    let symbol: String
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail ?? " ")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle(radius: 20)
    }
}

// MARK: - Verwachting

struct ForecastCard: View {
    let advice: StookAdvice

    var body: some View {
        let slots = advice.upcoming()
        let current = advice.currentSlot()

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Verwachting")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("per 6 uur")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(slots) { slot in
                        ForecastPill(slot: slot, isNow: slot.id == current?.id)
                    }
                }
                .padding(.vertical, 2)
            }

            // Tijdlijnbalk
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(slots) { slot in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(slot.code.color.opacity(slot.isFinal ? 1 : 0.55))
                    }
                }
                .frame(width: geo.size.width, height: 8)
            }
            .frame(height: 8)

            HStack(spacing: 14) {
                legendDot(opacity: 1, text: "Definitief")
                legendDot(opacity: 0.55, text: "Voorlopig")
            }
        }
        .padding(20)
        .cardStyle()
    }

    private func legendDot(opacity: Double, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.ember.opacity(opacity)).frame(width: 8, height: 8)
            Text(text).font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

struct ForecastPill: View {
    let slot: ForecastSlot
    let isNow: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(isNow ? "Nu" : NL.weekdayShort(slot.date))
                .font(.caption.weight(.bold))
                .foregroundStyle(isNow ? .white : Theme.ink)
            Text(NL.time(slot.date))
                .font(.caption2)
                .foregroundStyle(isNow ? .white.opacity(0.85) : Theme.muted)
            ZStack {
                Circle()
                    .fill(isNow ? AnyShapeStyle(Color.white) : AnyShapeStyle(slot.code.gradient))
                    .frame(width: 36, height: 36)
                Image(systemName: slot.code.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isNow ? slot.code.color : .white)
            }
            Text(slot.code.shortTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isNow ? .white : slot.code.textColor)
            if !slot.isFinal {
                Text("voorlopig")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isNow ? .white.opacity(0.8) : Theme.muted)
            }
        }
        .frame(width: 74)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isNow ? AnyShapeStyle(slot.code.gradient) : AnyShapeStyle(Theme.background))
        }
    }
}

// MARK: - Legenda

struct CodeLegendCard: View {
    let current: AdviceCode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Wat betekenen de codes?")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Theme.ink)

            ForEach(AdviceCode.allCases) { code in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(code.gradient)
                            .frame(width: 40, height: 40)
                        Image(systemName: code.symbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("\(code.title) · \(code.headline)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            if code == current {
                                Text("NU")
                                    .font(.system(size: 10, weight: .heavy))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(code.color.opacity(0.18), in: Capsule())
                                    .foregroundStyle(code.textColor)
                            }
                        }
                        Text(code.explanation)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Styling helpers

extension View {
    func cardStyle(radius: CGFloat = Theme.cornerRadius) -> some View {
        self
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.04), radius: 12, y: 6)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .background(
                LinearGradient(colors: [Theme.flameGold, Theme.ember], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
