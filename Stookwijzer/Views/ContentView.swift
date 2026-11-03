import SwiftUI

/// Kiest de layout: NavigationStack op iPhone, NavigationSplitView (zijbalk) op iPad.
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(PlaceStore.self) private var places
    @Environment(AdviceViewModel.self) private var advice
    @Environment(LocationManager.self) private var location
    @Environment(PushManager.self) private var push
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if sizeClass == .regular {
                SplitLayout()
            } else {
                PhoneLayout()
            }
        }
        .task {
            // Bij eerste start: locatie vragen als er nog niets is opgeslagen
            if places.saved.isEmpty || location.isAuthorized {
                await places.refreshCurrentLocation(using: location)
            }
            await reload()
            await push.update(places: places.all)
        }
        .onChange(of: places.all) { _, all in
            Task { await push.update(places: all) }
        }
        .onChange(of: push.openedPlaceID) { _, id in
            if let id, places.all.contains(where: { $0.id == id }) { places.selectedID = id }
            push.openedPlaceID = nil
        }
        .onChange(of: places.selectedID) {
            Task { await reload() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
    }

    private func reload(force: Bool = false) async {
        guard let place = places.selected else { return }
        await advice.load(for: place, force: force)
    }
}

// MARK: - iPhone

struct PhoneLayout: View {
    @Environment(PlaceStore.self) private var places
    @Environment(AdviceViewModel.self) private var advice
    @State private var showSearch = false
    @State private var showInfo = false
    @State private var showManage = false
    @State private var showNotifications = false
    @Environment(\.splashVisible) private var splashVisible

    var body: some View {
        NavigationStack {
            ScrollView {
                AdviceDetailView(onAddPlace: { showSearch = true })
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .refreshable {
                if let place = places.selected { await advice.load(for: place, force: true) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NotificationsButton { showNotifications = true }
                }
                ToolbarItem(placement: .principal) {
                    PlaceMenu(showSearch: $showSearch, showManage: $showManage)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Uitleg")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSearch) { PlaceSearchView() }
            .sheet(isPresented: $showInfo) { InfoView() }
            .sheet(isPresented: $showManage) { ManagePlacesView() }
            .sheet(isPresented: $showNotifications) { NotificationSettingsView() }
        }
        .reviewPrompt(isCalm: !splashVisible && !showSearch && !showInfo && !showManage && !showNotifications
                      && places.selected != nil)
    }
}

/// Plaatsnaam als knop in de navigatiebalk, met een menu om te wisselen.
struct PlaceMenu: View {
    @Environment(PlaceStore.self) private var places
    @Environment(LocationManager.self) private var location
    @Binding var showSearch: Bool
    @Binding var showManage: Bool

    var body: some View {
        Menu {
            ForEach(places.all) { place in
                Button {
                    places.selectedID = place.id
                } label: {
                    if place.id == places.selected?.id {
                        Label(place.name, systemImage: "checkmark")
                    } else {
                        Label(place.name, systemImage: place.isCurrentLocation ? "location.fill" : "mappin")
                    }
                }
            }
            Divider()
            if places.current == nil {
                Button {
                    Task { await places.refreshCurrentLocation(using: location) }
                } label: {
                    Label("Gebruik mijn locatie", systemImage: "location")
                }
            }
            Button { showSearch = true } label: {
                Label("Plaats toevoegen", systemImage: "plus")
            }
            if !places.saved.isEmpty {
                Button { showManage = true } label: {
                    Label("Plaatsen beheren", systemImage: "list.bullet")
                }
            }
        } label: {
            HStack(spacing: 6) {
                if places.selected?.isCurrentLocation == true {
                    Image(systemName: "location.fill").font(.caption)
                }
                Text(places.selected?.name ?? "Stookwijzer")
                    .font(.system(.headline, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Theme.hairline))
        }
    }
}

// MARK: - iPad

struct SplitLayout: View {
    @Environment(PlaceStore.self) private var places
    @Environment(AdviceViewModel.self) private var advice
    @Environment(LocationManager.self) private var location
    @State private var showSearch = false
    @State private var showInfo = false
    @State private var showNotifications = false
    @Environment(\.splashVisible) private var splashVisible

    var body: some View {
        @Bindable var places = places

        NavigationSplitView {
            List(selection: $places.selectedID) {
                Section("Huidige locatie") {
                    if let current = places.current {
                        PlaceRow(place: current).tag(Optional(current.id))
                    } else {
                        Button {
                            Task { await places.refreshCurrentLocation(using: location) }
                        } label: {
                            Label("Gebruik mijn locatie", systemImage: "location")
                        }
                    }
                }
                Section("Opgeslagen") {
                    ForEach(places.saved) { place in
                        PlaceRow(place: place).tag(Optional(place.id))
                    }
                    .onDelete { offsets in
                        offsets.map { places.saved[$0] }.forEach(places.remove)
                    }
                    .onMove(perform: places.move)

                    Button { showSearch = true } label: {
                        Label("Plaats toevoegen", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Stookwijzer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSearch = true } label: { Image(systemName: "plus") }
                }
            }
        } detail: {
            NavigationStack {
                ScrollView {
                    AdviceDetailView(onAddPlace: { showSearch = true }, wide: true)
                        .frame(maxWidth: 860)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                        .frame(maxWidth: .infinity)
                }
                .background(Theme.background.ignoresSafeArea())
                .refreshable {
                    if let place = places.selected { await advice.load(for: place, force: true) }
                }
                .navigationTitle(places.selected?.name ?? "Stookwijzer")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        NotificationsButton { showNotifications = true }
                        Button { showInfo = true } label: { Image(systemName: "info.circle") }
                    }
                }
            }
        }
        .sheet(isPresented: $showSearch) { PlaceSearchView() }
        .sheet(isPresented: $showInfo) { InfoView() }
        .sheet(isPresented: $showNotifications) { NotificationSettingsView() }
        .reviewPrompt(isCalm: !splashVisible && !showSearch && !showInfo && !showNotifications
                      && places.selected != nil)
    }
}

struct NotificationsButton: View {
    @Environment(PushManager.self) private var push
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: push.isEnabled ? "bell.badge.fill" : "bell")
        }
        .accessibilityLabel("Meldingen")
    }
}

struct PlaceRow: View {
    let place: Place

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                if let subtitle = place.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: place.isCurrentLocation ? "location.fill" : "mappin.circle.fill")
                .foregroundStyle(Theme.ember)
        }
    }
}
