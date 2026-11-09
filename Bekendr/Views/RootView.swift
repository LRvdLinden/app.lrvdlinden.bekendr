import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("onboarding.done") private var onboardingDone = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Query(sort: \Place.sortOrder) private var places: [Place]
    @State private var showSplash = true
    @State private var router = AppRouter.shared
    @State private var lock = AppLock.shared
    @State private var store = NoticeStore.shared
    @State private var addressToAdd: String?

    var body: some View {
        ZStack {
            if onboardingDone {
                MainTabs()
            } else {
                OnboardingView()
            }
            if lock.isLocked, onboardingDone {
                LockView()
                    .transition(.opacity)
            }
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: lock.isLocked)
        .environment(router)
        .environment(store)
        .task {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation { showSplash = false }
        }
        .task(id: places.map(\.key).joined() + places.map { "\($0.radius)\($0.categoriesRaw)\($0.latitude)" }.joined()) {
            guard onboardingDone else { return }
            await store.refresh(places: places.map(PlaceInfo.init), notify: false)
            WidgetSync.update(places: places.map(PlaceInfo.init))
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            checkSharedAddress()
            guard onboardingDone else { return }
            Task {
                await store.refreshIfStale(places: places.map(PlaceInfo.init))
                WidgetSync.update(places: places.map(PlaceInfo.init))
            }
        }
        .onChange(of: router.pendingAddress) { _, value in
            if let value { addressToAdd = value; router.pendingAddress = nil }
        }
        .sheet(item: Binding(get: { addressToAdd.map(PendingAddress.init) }, set: { addressToAdd = $0?.text })) { pending in
            NavigationStack {
                PlaceEditorView(place: nil, initialQuery: pending.text)
            }
        }
        .reviewPrompt(isCalm: onboardingDone && !lock.isLocked && !showSplash && addressToAdd == nil)
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 560)
        #endif
    }

    private func checkSharedAddress() {
        if let pending = SharedStore.pendingAddress, onboardingDone {
            SharedStore.pendingAddress = nil
            addressToAdd = pending
        }
    }
}

private struct PendingAddress: Identifiable {
    let text: String
    var id: String { text }
}

struct MainTabs: View {
    @Environment(AppRouter.self) private var router
    @Environment(NoticeStore.self) private var store
    @Query private var marks: [NoticeMark]

    var body: some View {
        @Bindable var router = router
        let unread = store.notices.filter(MarkIndex(marks).isUnread).count
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("Jouw buurt", systemImage: "house") }
                .tag(AppTab.home)
            InboxView()
                .tabItem { Label("Meldingen", systemImage: "tray") }
                .badge(unread)
                .tag(AppTab.inbox)
            SettingsView()
                .tabItem { Label("Instellingen", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}

/// Vergrendelscherm bij Face ID / Touch ID.
struct LockView: View {
    @State private var lock = AppLock.shared

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                BekendrMark(size: 84)
                Text("Bekendr is vergrendeld")
                    .font(.title3.weight(.semibold))
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Ontgrendel met \(lock.biometryName)", systemImage: "lock.open")
                        .font(.headline)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task { await lock.unlock() }
    }
}
