import Foundation
import SwiftUI

/// Indeling van bekendmakingen in Bekendr.
enum NoticeCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case permit, traffic, tree, event, plan, other

    var id: String { rawValue }

    /// Meervoud, voor tegels en filters.
    var name: String {
        switch self {
        case .permit: "Vergunningen"
        case .traffic: "Verkeer"
        case .tree: "Bomen en kap"
        case .event: "Evenementen"
        case .plan: "Ruimtelijke plannen"
        case .other: "Regels en overig"
        }
    }

    /// Enkelvoud, voor het label boven een melding.
    var label: String {
        switch self {
        case .permit: "Vergunning"
        case .traffic: "Verkeer"
        case .tree: "Bomen en kap"
        case .event: "Evenement"
        case .plan: "Ruimtelijk plan"
        case .other: "Overig"
        }
    }

    var symbol: String {
        switch self {
        case .permit: "house"
        case .traffic: "exclamationmark.triangle"
        case .tree: "tree"
        case .event: "ticket"
        case .plan: "map"
        case .other: "doc.text"
        }
    }

    /// Volle kleur voor punten op de kaart en iconen.
    var color: Color {
        switch self {
        case .permit: Color(hex: 0x2747E8)
        case .traffic: Color(hex: 0xE8743B)
        case .tree: Color(hex: 0x2E8B57)
        case .event: Color(hex: 0x7B4BD6)
        case .plan: Color(hex: 0x0F8A8A)
        case .other: Color(hex: 0x5B6275)
        }
    }

    /// Tekstkleur met voldoende contrast in licht en donker.
    var textColor: Color {
        switch self {
        case .permit: Color(light: 0x1B34B0, dark: 0x9DB0FF)
        case .traffic: Color(light: 0xA4461A, dark: 0xF4A47C)
        case .tree: Color(light: 0x1E6B40, dark: 0x7FD3A2)
        case .event: Color(light: 0x5A30AE, dark: 0xC2A6F5)
        case .plan: Color(light: 0x0B6767, dark: 0x7FD1D1)
        case .other: Color(light: 0x4A5168, dark: 0xB4BACB)
        }
    }

    /// Zachte achtergrond voor tegels en labels.
    var tint: Color {
        switch self {
        case .permit: Color(light: 0xE4E9FD, dark: 0x1D2547)
        case .traffic: Color(light: 0xFDEBE1, dark: 0x3A2418)
        case .tree: Color(light: 0xE0F2E8, dark: 0x16301F)
        case .event: Color(light: 0xEEE7FB, dark: 0x2A1F45)
        case .plan: Color(light: 0xDDF2F2, dark: 0x123131)
        case .other: Color(light: 0xECEEF3, dark: 0x262B38)
        }
    }

    /// Bepaalt de categorie aan de hand van titel, soort, onderwerp en samenvatting.
    static func classify(_ parts: [String]) -> NoticeCategory {
        let text = parts.joined(separator: " ").lowercased()
        func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        if has(["kapvergunning", "kappen", "kapmelding", "boom", "bomen", "houtopstand", "herplant"]) { return .tree }
        if has(["verkeersbesluit", "verkeersmaatregel", "wegafsluiting", "afsluiting van", "parkeerverbod",
                "parkeerplaats", "gehandicaptenparkeer", "laadpaal", "oplaadpunt", "verkeer", "wegwerk"]) { return .traffic }
        if has(["evenement", "festival", "kermis", "markt", "braderie", "optocht", "evenementenvergunning"]) { return .event }
        if has(["omgevingsplan", "bestemmingsplan", "ruimtelijk", "wijzigingsplan", "projectbesluit",
                "voorbereidingsbesluit", "structuurvisie", "omgevingsvisie", "ter inzage"]) { return .plan }
        if has(["vergunning", "omgevingsvergunning", "ontheffing", "aanvraag", "melding activiteitenbesluit"]) { return .permit }
        return .other
    }
}

/// Eén officiële bekendmaking zoals Bekendr hem bewaart.
struct Notice: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var date: Date
    var creator: String
    var type: String
    var subject: String
    var spatial: String
    var summary: String
    var url: URL
    var latitude: Double?
    var longitude: Double?
    var category: NoticeCategory
    /// Locaties (Place.id) waarbij deze melding hoort, met de afstand in meters (of -1 bij een gebied).
    var places: [String: Double]
    var firstSeen: Date
    /// Gevonden bij de allereerste controle van een locatie: telt niet als nieuw.
    var initial: Bool

    var hasCoordinate: Bool { latitude != nil && longitude != nil }
}

/// Gegevens voor de widget, gedeeld via de App Group.
struct WidgetSnapshot: Codable {
    struct Item: Codable, Hashable {
        var id: String
        var title: String
        var category: NoticeCategory
        var date: Date
        var place: String
    }
    var updated: Date
    var newCount: Int
    var todayCount: Int
    var weekCount: Int
    var placeName: String
    var items: [Item]

    static let empty = WidgetSnapshot(updated: .now, newCount: 0, todayCount: 0, weekCount: 0, placeName: "", items: [])
}
