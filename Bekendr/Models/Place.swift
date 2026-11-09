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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var key: String { id.uuidString }

    /// Korte omschrijving: "Voorbeeldstraat 12 · 500 m" of "Wijk Zuid · hele wijk".
    var detail: String {
        switch mode {
        case .radius: "\(shortAddress) · \(Format.distance(radius))"
        case .area: "\(shortAddress) · \(areaType?.whole ?? "heel gebied")"
        }
    }

    var shortAddress: String {
        address.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? address
    }

    var isConfigured: Bool { latitude != 0 && longitude != 0 }
}

enum PlaceMode: String, CaseIterable, Identifiable {
    case radius, area
    var id: String { rawValue }
    var label: String {
        switch self {
        case .radius: "Straal rond adres"
        case .area: "Wijk of gemeente"
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
