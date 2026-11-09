import SwiftUI
import SwiftData
#if os(iOS)
import BackgroundTasks
#endif

@main
struct BekendrApp: App {
    @AppStorage("ui.appearance") private var appearance: AppearanceSetting = .system
    @Environment(\.scenePhase) private var scenePhase

    static let container: ModelContainer = {
        let schema = Schema([Place.self, NoticeMark.self])
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: cloud) { return container }
        // Zonder iCloud (of bij een fout) gewoon lokaal bewaren.
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: local)
    }()

    init() {
        Notifier.shared.activate()
        Notifier.shared.onOpenNotice = { id in
            AppRouter.shared.tab = .inbox
            AppRouter.shared.openNoticeID = id.isEmpty ? nil : id
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.colorScheme)
                .tint(Theme.accent)
                .onOpenURL { AppRouter.shared.open(url: $0) }
        }
        .modelContainer(Self.container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                AppLock.shared.lockIfNeeded()
                #if os(iOS)
                Self.scheduleRefresh()
                #endif
            default: break
            }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh(AppConfig.refreshTaskID)) {
            await Self.backgroundRefresh()
        }
        #endif
        #if os(macOS)
        .defaultSize(width: 980, height: 760)
        #endif
    }

    /// Alle locaties als vaste kopie, voor het ophalen.
    @MainActor
    static func placeInfos() -> [PlaceInfo] {
        let context = container.mainContext
        let places = (try? context.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        return places.map(PlaceInfo.init)
    }

    #if os(iOS)
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppConfig.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    static func backgroundRefresh() async {
        scheduleRefresh()
        let infos = placeInfos()
        await NoticeStore.shared.refresh(places: infos, notify: true)
        WidgetSync.update(places: infos)
    }
    #endif
}

/// Werkt de widget bij met de juiste gelezen/prullenbak-stand.
@MainActor
enum WidgetSync {
    static func update(places: [PlaceInfo]) {
        let marks = (try? BekendrApp.container.mainContext.fetch(FetchDescriptor<NoticeMark>())) ?? []
        let index = MarkIndex(marks)
        let names = Dictionary(places.map { ($0.key, $0.name) }, uniquingKeysWith: { a, _ in a })
        NoticeStore.shared.updateWidget(isUnread: index.isUnread, isTrashed: index.isTrashed, placeNames: names)
    }
}
