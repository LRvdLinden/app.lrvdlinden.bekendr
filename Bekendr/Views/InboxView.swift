import SwiftUI
import SwiftData

enum InboxScope: String, CaseIterable, Identifiable, Hashable {
    case all, unread, saved, trash
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "Alles"
        case .unread: "Ongelezen"
        case .saved: "Bewaard"
        case .trash: "Prullenbak"
        }
    }
}

struct NoticeFilter: Hashable {
    var placeKey: String?
    var category: NoticeCategory?
    var scope: InboxScope
}

/// Filtert en groepeert meldingen; gedeeld door de inbox en de lijst vanaf de tegels.
struct NoticeQuery {
    let store: NoticeStore
    let marks: MarkIndex

    func list(_ f: NoticeFilter) -> [Notice] {
        var base: [Notice]
        switch f.scope {
        case .saved: base = marks.savedNotices(current: store.notices)
        case .trash: base = store.notices.filter(marks.isInTrash)
        case .unread: base = store.notices.filter(marks.isUnread)
        case .all: base = store.notices.filter { !marks.isTrashed($0) }
        }
        if let key = f.placeKey, f.scope != .saved { base = base.filter { $0.places[key] != nil } }
        if let c = f.category { base = base.filter { $0.category == c } }
        return base
    }

    static func grouped(_ notices: [Notice]) -> [(String, [Notice])] {
        var order: [String] = []
        var groups: [String: [Notice]] = [:]
        for n in notices {
            let label = Format.day(n.date)
            if groups[label] == nil { order.append(label) }
            groups[label, default: []].append(n)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }
}

/// Lijst met meldingen, met vegen om te bewaren of naar de prullenbak te verplaatsen.
struct NoticeListContent: View {
    let notices: [Notice]
    let scope: InboxScope
    let marks: MarkIndex
    let placeNames: [String: String]
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            ForEach(NoticeQuery.grouped(notices), id: \.0) { day, items in
                Section(day) {
                    ForEach(items) { notice in
                        NavigationLink(value: notice) {
                            NoticeRow(notice: notice, unread: marks.isUnread(notice), placeNames: placeNames)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if scope == .trash {
                                Button("Verwijder", systemImage: "trash.slash", role: .destructive) {
                                    MarkActions.deleteForever(notice, in: context)
                                }
                                Button("Zet terug", systemImage: "arrow.uturn.backward") {
                                    MarkActions.restore(notice, in: context)
                                }
                                .tint(Theme.accentFill)
                            } else {
                                Button("Prullenbak", systemImage: "trash", role: .destructive) {
                                    MarkActions.trash(notice, in: context)
                                }
                                Button(marks.isSaved(notice) ? "Niet bewaren" : "Bewaren",
                                       systemImage: marks.isSaved(notice) ? "bookmark.slash" : "bookmark") {
                                    MarkActions.toggleSaved(notice, in: context)
                                }
                                .tint(Theme.accentFill)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if scope != .trash {
                                Button(marks.isUnread(notice) ? "Gelezen" : "Ongelezen",
                                       systemImage: marks.isUnread(notice) ? "envelope.open" : "envelope.badge") {
                                    MarkActions.setRead(notice, marks.isUnread(notice), in: context)
                                }
                                .tint(Color(hex: 0x5B6275))
                            }
                        }
                        .contextMenu {
                            Button(marks.isSaved(notice) ? "Niet bewaren" : "Bewaren", systemImage: "bookmark") {
                                MarkActions.toggleSaved(notice, in: context)
                            }
                            ShareLink(item: notice.url, subject: Text(notice.title)) {
                                Label("Deel", systemImage: "square.and.arrow.up")
                            }
                            if scope == .trash {
                                Button("Zet terug", systemImage: "arrow.uturn.backward") { MarkActions.restore(notice, in: context) }
                            } else {
                                Button("Naar prullenbak", systemImage: "trash", role: .destructive) { MarkActions.trash(notice, in: context) }
                            }
                        }
                    }
                }
            }
            if scope == .trash, !notices.isEmpty {
                Section {} footer: {
                    Text("Na 30 dagen worden meldingen in de prullenbak verwijderd. Tot die tijd kun je ze terugzetten.")
                }
            }
        }
        .groupedList()
    }
}

struct EmptyNotices: View {
    let scope: InboxScope
    @Environment(NoticeStore.self) private var store

    var body: some View {
        switch scope {
        case .saved:
            ContentUnavailableView("Nog niets bewaard", systemImage: "bookmark",
                                   description: Text("Bewaar een melding om hem hier terug te vinden."))
        case .trash:
            ContentUnavailableView("De prullenbak is leeg", systemImage: "trash",
                                   description: Text("Meldingen die je weggooit, staan hier nog 30 dagen."))
        default:
            if store.isLoading {
                ProgressView("Bekendmakingen ophalen…")
            } else if let error = store.lastError {
                ContentUnavailableView("Ophalen lukte niet", systemImage: "wifi.exclamationmark", description: Text(error))
            } else {
                ContentUnavailableView("Niets nieuws in je buurt", systemImage: "checkmark.circle",
                                       description: Text("Er zijn geen bekendmakingen die bij je filters passen."))
            }
        }
    }
}

/// Het tabblad Meldingen: lijst of kaart, met filters.
struct InboxView: View {
    @Environment(NoticeStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \Place.sortOrder) private var places: [Place]
    @Query private var marks: [NoticeMark]
    @AppStorage("inbox.showMap") private var showMap = false
    @State private var placeKey: String?
    @State private var scope: InboxScope = .all
    @State private var path = NavigationPath()

    var body: some View {
        let index = MarkIndex(marks)
        let query = NoticeQuery(store: store, marks: index)
        let filter = NoticeFilter(placeKey: placeKey, category: nil, scope: scope)
        let notices = query.list(filter)
        let names = Dictionary(places.map { ($0.key, $0.name) }, uniquingKeysWith: { a, _ in a })

        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                controls
                if showMap {
                    NoticeMapView(notices: notices, places: placeFilterList, marks: index, placeNames: names)
                } else if notices.isEmpty {
                    EmptyNotices(scope: scope).frame(maxHeight: .infinity)
                } else {
                    NoticeListContent(notices: notices, scope: scope, marks: index, placeNames: names)
                }
            }
            .background(Theme.background)
            .navigationTitle("Meldingen")
            .largeTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Markeer alles als gelezen", systemImage: "envelope.open") {
                            MarkActions.markAllRead(store.notices, in: context)
                            WidgetSync.update(places: places.map(PlaceInfo.init))
                        }
                        Button("Nu controleren", systemImage: "arrow.clockwise") {
                            Task {
                                await store.refresh(places: places.map(PlaceInfo.init), notify: false)
                                WidgetSync.update(places: places.map(PlaceInfo.init))
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Meer opties")
                }
            }
            .refreshable {
                await store.refresh(places: places.map(PlaceInfo.init), notify: false)
                WidgetSync.update(places: places.map(PlaceInfo.init))
            }
            .navigationDestination(for: Notice.self) { NoticeDetailView(notice: $0) }
        }
        .onChange(of: router.openNoticeID, initial: true) { _, id in
            guard let id else { return }
            router.openNoticeID = nil
            showMap = false
            if let notice = store.notice(id: id) ?? index.savedNotices(current: []).first(where: { $0.id == id }) {
                path = NavigationPath()
                path.append(notice)
            }
        }
        .onChange(of: marks.count) { _, _ in WidgetSync.update(places: places.map(PlaceInfo.init)) }
    }

    private var placeFilterList: [Place] {
        guard let placeKey else { return places }
        return places.filter { $0.key == placeKey }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Weergave", selection: $showMap) {
                Text("Lijst").tag(false)
                Text("Kaart").tag(true)
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        Picker("Locatie", selection: $placeKey) {
                            Text("Alle locaties").tag(String?.none)
                            ForEach(places) { Text($0.name).tag(Optional($0.key)) }
                        }
                    } label: {
                        chip(title: places.first { $0.key == placeKey }?.name ?? "Alle locaties", on: true, chevron: true)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)

                    ForEach([InboxScope.unread, .saved, .trash]) { s in
                        Button {
                            scope = scope == s ? .all : s
                        } label: {
                            chip(title: s.label, on: scope == s, chevron: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sensoryFeedback(.selection, trigger: scope)
    }

    private func chip(title: String, on: Bool, chevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
            if chevron { Image(systemName: "chevron.down").font(.caption2.weight(.bold)) }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12).frame(height: 34)
        .foregroundStyle(on ? Color.white : Color.primary)
        .background(on ? Theme.home : Theme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(on ? .clear : Theme.line))
    }
}

/// Lijst die opent vanaf een tegel of de samenvatting op Jouw buurt.
struct NoticeListScreen: View {
    let filter: NoticeFilter
    @Environment(NoticeStore.self) private var store
    @Query(sort: \Place.sortOrder) private var places: [Place]
    @Query private var marks: [NoticeMark]

    var body: some View {
        let index = MarkIndex(marks)
        let notices = NoticeQuery(store: store, marks: index).list(filter)
        let names = Dictionary(places.map { ($0.key, $0.name) }, uniquingKeysWith: { a, _ in a })
        Group {
            if notices.isEmpty {
                EmptyNotices(scope: filter.scope)
            } else {
                NoticeListContent(notices: notices, scope: filter.scope, marks: index, placeNames: names)
            }
        }
        .background(Theme.background)
        .navigationTitle(title)
        .inlineTitle()
    }

    private var title: String {
        if let c = filter.category { return c.name }
        switch filter.scope {
        case .unread: return "Nieuw"
        case .saved: return "Bewaard"
        case .trash: return "Prullenbak"
        case .all: return "Meldingen"
        }
    }
}
