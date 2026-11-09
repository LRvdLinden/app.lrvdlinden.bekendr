import SwiftUI
import SwiftData

/// Welkom in drie stappen: uitleg, eerste locatie, straal en categorieën.
struct OnboardingView: View {
    @AppStorage("onboarding.done") private var onboardingDone = false
    @Environment(\.modelContext) private var context
    @Query private var places: [Place]
    @State private var step = 0
    @State private var draft = PlaceDraft()
    @State private var wantsNotifications = true
    @State private var finishing = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: intro
                case 1: chooseLocation
                default: chooseOptions
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))

            footer
                .frame(maxWidth: 560)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(step == 0 ? Theme.home : Theme.background)
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: Stappen

    private var intro: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().strokeBorder(Color(hex: 0x8A9DFF).opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 6]))
                    .frame(width: 230, height: 230)
                Circle().fill(Theme.accentFill.opacity(0.22)).frame(width: 150, height: 150)
                Image(systemName: "house.fill")
                    .font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 52, height: 52).background(Color(hex: 0x4C6BFF), in: Circle())
                ForEach(Array([NoticeCategory.permit, .traffic, .tree, .event].enumerated()), id: \.offset) { i, c in
                    let angle = Angle.degrees(Double(i) * 90 - 50)
                    Image(systemName: c.symbol)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(c.color, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .offset(x: cos(angle.radians) * 100, y: sin(angle.radians) * 100)
                }
            }
            .accessibilityHidden(true)
            VStack(spacing: 14) {
                Text("Weet wat er in je buurt gebeurt")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("Vergunningen, verkeersbesluiten, kap en evenementen: alle officiële bekendmakingen rond je adres, op één plek.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: 0xC4CAE0))
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var chooseLocation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepHeader(title: "Kies je eerste locatie",
                           text: "Ieder adres in Nederland kan. Later voeg je er meer toe, zoals je werk of een wijk.")
                Picker("Soort", selection: $draft.mode) {
                    ForEach(PlaceMode.allCases.filter { $0 != .route }) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if draft.mode == .area {
                    AreaPicker(areas: $draft.areas)
                } else {
                    LocationSearchField(mode: .radius, selection: $draft.location)
                }
                if draft.isValid {
                    PlaceMapPreview(locations: draft.previewLocations, mode: draft.mode, radius: draft.radius)
                }
            }
            .padding(24)
        }
        .onChange(of: draft.mode) { _, mode in
            if mode == .area { draft.location = nil } else { draft.areas = [] }
        }
    }

    private var chooseOptions: some View {
        Form {
            Section {
                stepHeader(title: "Wat wil je volgen?",
                           text: "Stel in hoe ver om je heen je wilt kijken en welke soorten bekendmakingen je wilt zien.")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                if draft.isValid {
                    PlaceMapPreview(locations: draft.previewLocations, mode: draft.mode, radius: draft.radius)
                        .listRowInsets(EdgeInsets())
                }
            }
            PlaceOptionsSection(draft: $draft)
            Section {
                Toggle("Stuur een melding bij iets nieuws", isOn: $wantsNotifications)
            } footer: {
                Text("Bekendr kijkt zelf regelmatig of er iets nieuws is. Tussen 22:00 en 07:00 komen meldingen stil binnen.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func stepHeader(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title.weight(.bold))
            Text(text).foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    // MARK: Onderkant

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i == step ? Color(hex: 0x8A9DFF) : (step == 0 ? Color(hex: 0x3A4060) : Theme.line))
                        .frame(width: i == step ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Stap \(step + 1) van 3")

            Button {
                next()
            } label: {
                Group {
                    if finishing { ProgressView().tint(.white) } else { Text(step == 2 ? "Aan de slag" : (step == 0 && !places.isEmpty ? "Sluiten" : "Volgende")) }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(canContinue ? Theme.accentFill : Theme.accentFill.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canContinue || finishing)

            if step == 0 {
                Text("Gegevens van officielebekendmakingen.nl (KOOP) en PDOK")
                    .font(.caption).foregroundStyle(Color(hex: 0xA3AAC4))
            } else {
                Button("Terug") { step -= 1 }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case 1: draft.isValid
        case 2: draft.isValid
        default: true
        }
    }

    private func next() {
        // Opnieuw bekeken vanuit Instellingen: alleen de uitleg, geen nieuwe locatie.
        if step == 0, !places.isEmpty { onboardingDone = true; return }
        guard step == 2 else { step += 1; return }
        finishing = true
        Task {
            if wantsNotifications { _ = await Notifier.shared.requestPermission() }
            let place = Place()
            place.sortOrder = places.count
            if draft.name.isEmpty { draft.name = "Thuis" }
            draft.apply(to: place)
            context.insert(place)
            try? context.save()
            finishing = false
            onboardingDone = true
        }
    }
}
