import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Place.sortOrder) private var places: [Place]
    @Query private var marks: [NoticeMark]
    @AppStorage("ui.appearance") private var appearance: AppearanceSetting = .system
    @AppStorage("onboarding.done") private var onboardingDone = true
    @AppStorage("notify.enabled") private var notifyEnabled = false
    @AppStorage("notify.quiet") private var quietEnabled = true
    @AppStorage("notify.quietStart") private var quietStart = 22
    @AppStorage("notify.quietEnd") private var quietEnd = 7
    @State private var lock = AppLock.shared
    @State private var editing: Place?
    @State private var adding = false
    @State private var showWhatsNew = false
    @Environment(NoticeStore.self) private var store

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(places) { place in
                        Button { editing = place } label: {
                            HStack(spacing: 12) {
                                Image(systemName: place.symbol)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 32, height: 32)
                                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name).foregroundStyle(.primary)
                                    Text("\(place.detail) · \(place.categories.count) categorieën")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                    .onMove(perform: move)
                    Button { adding = true } label: {
                        Label("Locatie toevoegen", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Mijn locaties")
                }

                Section("Meldingen en beveiliging") {
                    Toggle("Melding bij nieuwe bekendmaking", isOn: Binding(
                        get: { notifyEnabled },
                        set: { on in
                            if on { Task { _ = await Notifier.shared.requestPermission() } } else { notifyEnabled = false }
                        }))
                    if notifyEnabled {
                        Toggle("Stille uren", isOn: $quietEnabled)
                        if quietEnabled {
                            Picker("Van", selection: $quietStart) { hours }
                            Picker("Tot", selection: $quietEnd) { hours }
                        }
                    }
                    if lock.isAvailable {
                        Toggle("Vergrendel met \(lock.biometryName)", isOn: Binding(
                            get: { lock.isEnabled },
                            set: { on in Task { await lock.setEnabled(on) } }))
                    }
                }

                Section {
                    NavigationLink(value: NoticeFilter(placeKey: nil, category: nil, scope: .saved)) {
                        LabeledContent("Bewaarde meldingen", value: "\(MarkIndex(marks).savedNotices(current: store.notices).count)")
                    }
                    NavigationLink(value: NoticeFilter(placeKey: nil, category: nil, scope: .trash)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prullenbak")
                            Text("Na 30 dagen definitief verwijderd").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Weergave") {
                    Picker("Weergave", selection: $appearance) {
                        ForEach(AppearanceSetting.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Link(destination: AppConfig.privacyURL) {
                        Label("Privacyverklaring", systemImage: "hand.raised")
                    }
                    Link(destination: AppConfig.supportURL) {
                        Label("Support en contact", systemImage: "questionmark.circle")
                    }
                    Button { showWhatsNew = true } label: {
                        Label("Wat is nieuw", systemImage: "sparkles")
                    }
                    Button { onboardingDone = false } label: {
                        Label("Toon het welkomstscherm", systemImage: "hand.wave")
                    }
                    Link(destination: AppConfig.sourceURL) {
                        Label("Bron: officielebekendmakingen.nl", systemImage: "building.columns")
                    }
                } footer: {
                    Text("Bekendr is geen app van de overheid. De gegevens komen van KOOP en PDOK en worden rechtstreeks op je toestel opgehaald.")
                }

                Section {
                    MoreAppsCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text(MoreAppsText.current.section)
                }

                Section {
                    AppInfoFooter()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Instellingen")
            .largeTitle()
            .navigationDestination(for: NoticeFilter.self) { NoticeListScreen(filter: $0) }
            .navigationDestination(for: Notice.self) { NoticeDetailView(notice: $0) }
            .sheet(item: $editing) { place in NavigationStack { PlaceEditorView(place: place) } }
            .sheet(isPresented: $adding) { NavigationStack { PlaceEditorView(place: nil) } }
            .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
        }
    }

    @ViewBuilder
    private var hours: some View {
        ForEach(0..<24, id: \.self) { h in Text(String(format: "%02d:00", h)).tag(h) }
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { context.delete(places[i]) }
        try? context.save()
    }

    private func move(_ source: IndexSet, _ destination: Int) {
        var list = places
        list.move(fromOffsets: source, toOffset: destination)
        for (i, place) in list.enumerated() { place.sortOrder = i }
        try? context.save()
    }
}

/// Wat er nieuw is in deze versie.
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Versie 1.0") {
                    Label("Officiële bekendmakingen rond je adres, wijk of gemeente", systemImage: "mappin.and.ellipse")
                    Label("Buurten en wijken samenvoegen tot één locatie", systemImage: "square.on.square.dashed")
                    Label("Meldingen als lijst of op de kaart", systemImage: "map")
                    Label("Bewaren, prullenbak en gelezen via iCloud op al je apparaten", systemImage: "icloud")
                    Label("Melding bij iets nieuws, met stille uren", systemImage: "bell.badge")
                    Label("Widget voor je beginscherm", systemImage: "square.grid.2x2")
                }
            }
            .navigationTitle("Wat is nieuw")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klaar") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }
}
