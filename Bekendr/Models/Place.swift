import Foundation
import SwiftData
import CoreLocation

/// Een gevolgde locatie: een adres met een straal, of een heel gebied (woonplaats, wijk, buurt of gemeente).
/// Wordt via iCloud gesynchroniseerd; daarom heeft elk veld een standaardwaarde.
@Model
final class Place {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "mappin"
    var address: String = ""
    var pdokID: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var radius: Double = 500
    var modeRaw: String = PlaceMode.radius.rawValue
    var areaTypeRaw: String = ""
    var municipality: String = ""
    var minLatitude: Double = 0
    var maxLatitude: Double = 0
    var minLongitude: Double = 0
    var maxLongitude: Double = 0
    var categoriesRaw: String = NoticeCategory.allCases.map(\.rawValue).joined(separator: ",")
    /// Samengevoegde gebieden (buurten, wijken, woonplaatsen, gemeenten) als JSON.
    var areasJSON: String = ""
    /// Gevolgde route (alleen iPhone, iPad en Mac) als JSON.
    var routeJSON: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(name: String = "", symbol: String = "mappin") {
        self.id = UUID()
        self.name = name
        self.symbol = symbol
        self.createdAt = Date()
    }

    var mode: PlaceMode {
        get { PlaceMode(rawValue: modeRaw) ?? .radius }
        set { modeRaw = newValue.rawValue }
    }

    var areaType: AreaType? {
        get { AreaType(rawValue: areaTypeRaw) }
        set { areaTypeRaw = newValue?.rawValue ?? "" }
    }

    var categories: Set<NoticeCategory> {
        get { Set(categoriesRaw.split(separator: ",").compactMap { NoticeCategory(rawValue: String($0)) }) }
        set { categoriesRaw = NoticeCategory.allCases.filter(newValue.contains).map(\.rawValue).joined(separator: ",") }
    }

    /// De gebieden die samen deze locatie vormen. Oudere locaties met één gebied worden als één gebied gelezen.
    var areas: [AreaRef] {
        get {
            if let list = try? JSONDecoder().decode([AreaRef].self, from: Data(areasJSON.utf8)), !list.isEmpty { return list }
            guard mode == .area, !pdokID.isEmpty else { return [] }
            let first = address.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? address
            return [AreaRef(id: pdokID, name: first, type: areaTypeRaw, municipality: municipality,
                            latitude: latitude, longitude: longitude,
                            minLat: minLatitude, maxLat: maxLatitude, minLon: minLongitude, maxLon: maxLongitude)]
        }
        set {
            areasJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
    }

    var route: RouteInfo? {
        get { try? JSONDecoder().decode(RouteInfo.self, from: Data(routeJSON.utf8)) }
        set { routeJSON = newValue.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) } ?? "" }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var key: String { id.uuidString }

    /// Korte omschrijving: "Voorbeeldstraat 12 · 500 m" of "Wijk Zuid · hele wijk".
    var detail: String {
        switch mode {
        case .radius: "\(shortAddress) · \(Format.distance(radius))"
        case .area:
            areas.count > 1 ? "\(areas.count) gebieden samengevoegd" : "\(shortAddress) · \(areaType?.whole ?? "heel gebied")"
        case .route: "\(shortAddress) · \(Format.distance(radius)) langs de route"
        }
    }

    var shortAddress: String {
        if mode == .area, areas.count > 1 { return areas.map(\.name).joined(separator: " + ") }
        if mode == .route, let route { return route.title }
        return address.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? address
    }

    var isConfigured: Bool { latitude != 0 && longitude != 0 }
}

/// Eén gebied binnen een (samengevoegde) locatie.
struct AreaRef: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var type: String
    var municipality: String
    var latitude: Double
    var longitude: Double
    var minLat: Double
    var maxLat: Double
    var minLon: Double
    var maxLon: Double

    var bounds: KoopClient.Bounds? {
        maxLat > minLat && maxLon > minLon ? .init(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon) : nil
    }

    init(id: String, name: String, type: String, municipality: String, latitude: Double, longitude: Double,
         minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.id = id; self.name = name; self.type = type; self.municipality = municipality
        self.latitude = latitude; self.longitude = longitude
        self.minLat = minLat; self.maxLat = maxLat; self.minLon = minLon; self.maxLon = maxLon
    }

    init(_ l: PDOKClient.Location) {
        self.init(id: l.id, name: l.name, type: l.type, municipality: l.municipality,
                  latitude: l.latitude, longitude: l.longitude,
                  minLat: l.bounds?.minLat ?? 0, maxLat: l.bounds?.maxLat ?? 0,
                  minLon: l.bounds?.minLon ?? 0, maxLon: l.bounds?.maxLon ?? 0)
    }

    var location: PDOKClient.Location {
        .init(id: id, label: name, type: type, name: name, latitude: latitude, longitude: longitude,
              municipality: municipality, bounds: bounds, polygons: [])
    }
}

enum PlaceMode: String, CaseIterable, Identifiable {
    case radius, area, route
    var id: String { rawValue }
    var label: String {
        switch self {
        case .radius: "Rond adres"
        case .area: "Wijk of gemeente"
        case .route: "Route"
        }
    }
}

enum AreaType: String, CaseIterable, Identifiable {
    case woonplaats, wijk, buurt, gemeente
    var id: String { rawValue }
    var label: String {
        switch self {
        case .woonplaats: "Woonplaats"
        case .wijk: "Wijk"
        case .buurt: "Buurt"
        case .gemeente: "Gemeente"
        }
    }
    var whole: String {
        switch self {
        case .woonplaats: "hele woonplaats"
        case .wijk: "hele wijk"
        case .buurt: "hele buurt"
        case .gemeente: "hele gemeente"
        }
    }
}

/// Wat de gebruiker met een melding deed: gelezen, bewaard of naar de prullenbak.
/// Ook via iCloud gesynchroniseerd. Een bewaarde melding bewaart zijn eigen kopie,
/// zodat hij blijft staan als hij uit de lijst van de afgelopen weken valt.
@Model
final class NoticeMark {
    var noticeID: String = ""
    var isRead: Bool = false
    var isSaved: Bool = false
    var trashedAt: Date?
    var savedCopy: Data?
    var updatedAt: Date = Date()

    init(noticeID: String) {
        self.noticeID = noticeID
        self.updatedAt = Date()
    }

    var isTrashed: Bool { trashedAt != nil }
}
