import Foundation
import CoreLocation
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Een vaste kopie van een locatie, los van SwiftData, zodat het ophalen op de achtergrond kan lopen.
struct PlaceInfo: Hashable {
    var key: String
    var name: String
    var mode: PlaceMode
    var areaType: AreaType?
    var areaName: String
    var pdokID: String
    var latitude: Double
    var longitude: Double
    var radius: Double
    var municipality: String
    var bounds: KoopClient.Bounds?
    var categories: Set<NoticeCategory>
    var createdAt: Date
    var areas: [AreaRef]
    var route: RouteInfo?

    init(_ place: Place) {
        key = place.key
        name = place.name
        mode = place.mode
        areaType = place.areaType
        areaName = place.shortAddress
        pdokID = place.pdokID
        latitude = place.latitude
        longitude = place.longitude
        radius = place.radius
        municipality = place.municipality
        if place.maxLatitude > place.minLatitude, place.maxLongitude > place.minLongitude {
            bounds = .init(minLat: place.minLatitude, maxLat: place.maxLatitude,
                           minLon: place.minLongitude, maxLon: place.maxLongitude)
        }
        categories = place.categories
        createdAt = place.createdAt
        areas = place.areas
        route = place.mode == .route ? place.route : nil
    }
}

/// Houdt de opgehaalde bekendmakingen bij, bewaart ze op het toestel en meldt nieuwe.
@MainActor
@Observable
final class NoticeStore {
    static let shared = NoticeStore()

    /// Bekendmakingen van de afgelopen tijd, nieuwste eerst.
    private(set) var notices: [Notice] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastRefresh: Date?

    /// Hoeveel dagen terug Bekendr zoekt en bewaart.
    static let days = 30

    private let koop = KoopClient()
    private let pdok = PDOKClient()
    private var areaPolygons: [String: [[CLLocationCoordinate2D]]] = [:]
    private var refreshTask: Task<Int, Never>?

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bekendr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notices.json")
    }

    private init() {
        load()
        lastRefresh = UserDefaults.standard.object(forKey: "notices.lastRefresh") as? Date
    }

    // MARK: Vragen

    func notices(for placeKey: String?) -> [Notice] {
        guard let placeKey else { return notices }
        return notices.filter { $0.places[placeKey] != nil }
    }

    func notice(id: String) -> Notice? { notices.first { $0.id == id } }

    // MARK: Ophalen

    /// Haalt voor alle locaties de bekendmakingen op. Geeft het aantal nieuwe terug.
    @discardableResult
    func refresh(places: [PlaceInfo], notify: Bool) async -> Int {
        if let refreshTask { return await refreshTask.value }
        let task = Task { await performRefresh(places: places, notify: notify) }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }

    private func performRefresh(places: [PlaceInfo], notify: Bool) async -> Int {
        let configured = places.filter { $0.latitude != 0 }
        guard !configured.isEmpty else {
            notices = []
            save()
            return 0
        }
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let now = Date()
        var known = Dictionary(uniqueKeysWithValues: notices.map { ($0.id, $0) })
        let checked = Set(UserDefaults.standard.stringArray(forKey: "notices.checkedPlaces") ?? [])
        var newlyChecked = checked
        var fresh: [Notice] = []
        var failures = 0
        var placeKeysFound: [String: [String: Double]] = [:]

        for place in configured {
            do {
                let found = try await fetch(for: place)
                let isFirstCheck = !checked.contains(place.key)
                for var notice in found {
                    let distance = notice.places[place.key] ?? -1
                    placeKeysFound[notice.id, default: [:]][place.key] = distance
                    if known[notice.id] == nil {
                        notice.firstSeen = now
                        notice.initial = isFirstCheck
                        notice.places = [:]
                        known[notice.id] = notice
                        if !isFirstCheck { fresh.append(notice) }
                    }
                }
                newlyChecked.insert(place.key)
            } catch {
                failures += 1
                lastError = error.localizedDescription
            }
        }

        // Locaties per melding opnieuw vastleggen; meldingen van verwijderde locaties vallen weg.
        let activeKeys = Set(configured.map(\.key))
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.days, to: now) ?? now
        var merged: [Notice] = []
        for var notice in known.values {
            if let fromThisRun = placeKeysFound[notice.id] {
                notice.places = fromThisRun
            } else {
                notice.places = notice.places.filter { activeKeys.contains($0.key) }
            }
            if notice.places.isEmpty || notice.date < cutoff { continue }
            merged.append(notice)
        }
        merged.sort { $0.date != $1.date ? $0.date > $1.date : $0.firstSeen > $1.firstSeen }
        notices = merged
        if failures < configured.count {
            lastError = failures > 0 ? lastError : nil
            lastRefresh = now
            UserDefaults.standard.set(now, forKey: "notices.lastRefresh")
            UserDefaults.standard.set(Array(newlyChecked), forKey: "notices.checkedPlaces")
        }
        save()

        let freshNotices = fresh.compactMap { n in merged.first { $0.id == n.id } }
        if notify, !freshNotices.isEmpty {
            await Notifier.shared.announce(freshNotices, places: configured)
        }
        return freshNotices.count
    }

    private func fetch(for place: PlaceInfo) async throws -> [Notice] {
        let here = CLLocation(latitude: place.latitude, longitude: place.longitude)
        var queries: [String] = []
        switch place.mode {
        case .radius:
            queries = [KoopClient.radiusQuery(lat: place.latitude, lon: place.longitude, radius: place.radius, days: Self.days)]
        case .area:
            // Elk gebied apart opvragen; samen vormen ze één locatie.
            let areas = place.areas
            for area in areas {
                if let bounds = area.bounds {
                    queries += KoopClient.tiles(for: bounds).map { KoopClient.boxQuery($0, days: Self.days) }
                } else {
                    queries.append(KoopClient.radiusQuery(lat: area.latitude, lon: area.longitude, radius: 1500, days: Self.days))
                }
                if let q = KoopClient.nameQuery(area.name, days: Self.days) { queries.append(q) }
                if area.type == "gemeente", let q = KoopClient.creatorQuery(area.municipality.isEmpty ? area.name : area.municipality, days: Self.days) {
                    queries.append(q)
                }
            }
        case .route:
            // Rechthoeken langs de route; daarna alleen wat echt binnen de afstand tot de lijn ligt.
            for box in (place.route?.searchBoxes(margin: place.radius) ?? []).prefix(30) {
                queries += KoopClient.tiles(for: box).map { KoopClient.boxQuery($0, days: Self.days) }
            }
        }

        var polygons: [[CLLocationCoordinate2D]] = []
        if place.mode == .area {
            for area in place.areas where !area.id.isEmpty {
                if let cached = areaPolygons[area.id] {
                    polygons += cached
                } else if let location = try? await pdok.lookup(area.id) {
                    areaPolygons[area.id] = location.polygons
                    polygons += location.polygons
                }
            }
        }

        var result: [String: Notice] = [:]
        for query in queries {
            let records = try await koop.fetch(query: query)
            for record in records {
                guard var notice = KoopClient.notice(from: record) else { continue }
                guard place.categories.contains(notice.category) else { continue }
                if let lat = notice.latitude, let lon = notice.longitude {
                    let point = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    switch place.mode {
                    case .radius:
                        let d = here.distance(from: CLLocation(latitude: lat, longitude: lon))
                        // Kleine marge: KOOP rekent ook met afgeleide gebieden.
                        if d > place.radius * 1.15 { continue }
                        notice.places[place.key] = d
                    case .area:
                        if !polygons.isEmpty, !PDOKClient.contains(polygons, point) { continue }
                        notice.places[place.key] = -1
                    case .route:
                        guard let route = place.route else { continue }
                        let d = route.distance(to: point)
                        if d > place.radius * 1.15 { continue }
                        notice.places[place.key] = d
                    }
                } else {
                    // Zonder punt is niet te zeggen of een melding langs de route ligt.
                    if place.mode == .route { continue }
                    notice.places[place.key] = -1
                }
                result[notice.id] = notice
            }
        }
        return Array(result.values)
    }

    /// Haalt alleen op als de laatste keer langer dan `minutes` geleden was.
    func refreshIfStale(places: [PlaceInfo], minutes: Double = 15) async {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < minutes * 60, !notices.isEmpty { return }
        await refresh(places: places, notify: true)
    }

    // MARK: Opslag en widget

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: cacheURL),
           let list = try? decoder.decode([Notice].self, from: data) {
            notices = list
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(notices) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }

    /// Werkt de widget bij met de stand van nu.
    func updateWidget(isUnread: (Notice) -> Bool, isTrashed: (Notice) -> Bool, placeNames: [String: String]) {
        let visible = notices.filter { !isTrashed($0) }
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        let snapshot = WidgetSnapshot(
            updated: .now,
            newCount: visible.filter(isUnread).count,
            todayCount: visible.filter { cal.isDateInToday($0.date) }.count,
            weekCount: visible.filter { $0.date >= weekAgo }.count,
            placeName: placeNames.count == 1 ? (placeNames.values.first ?? "") : "",
            items: visible.prefix(6).map {
                .init(id: $0.id, title: $0.title, category: $0.category, date: $0.date,
                      place: $0.places.keys.compactMap { placeNames[$0] }.first ?? "")
            })
        SharedStore.saveSnapshot(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
