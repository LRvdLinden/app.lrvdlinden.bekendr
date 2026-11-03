import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// Kleur met dark-mode-variant (zelfde helper als in Homey Store `Core/Theme.swift`).
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            let v = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }

    /// Kleur die meebeweegt met licht/donker.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

enum Theme {
    static let background = Color.dynamic(light: 0xFAF6F1, dark: 0x121113)
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x1D1B1E)
    static let ink = Color.dynamic(light: 0x2A2320, dark: 0xF4EFEA)
    static let muted = Color.dynamic(light: 0x7D716A, dark: 0xA79E98)
    static let hairline = Color.dynamic(light: 0xEFE7DF, dark: 0x2C292D)

    static let ember = Color(hex: 0xF76B15)
    static let flameRed = Color(hex: 0xE5484D)
    static let flameGold = Color(hex: 0xFFB224)
    static let flameCore = Color(hex: 0xFFE27A)

    static let cornerRadius: CGFloat = 26
}

extension AdviceCode {
    var title: String {
        switch self {
        case .yellow: return "Code geel"
        case .orange: return "Code oranje"
        case .red: return "Code rood"
        }
    }

    var shortTitle: String {
        switch self {
        case .yellow: return "Geel"
        case .orange: return "Oranje"
        case .red: return "Rood"
        }
    }

    var headline: String {
        switch self {
        case .yellow: return "Stoken kan"
        case .orange: return "Liever niet stoken"
        case .red: return "Niet stoken"
        }
    }

    var explanation: String {
        switch self {
        case .yellow:
            return "De omstandigheden zijn redelijk. Stook je toch, let dan op droog hout, een goed trekkende kachel en eventuele overlast voor je buren."
        case .orange:
            return "Door weinig wind of matige luchtkwaliteit blijft rook langer hangen. De kans op overlast en gezondheidsklachten in de buurt is groter."
        case .red:
            return "Rook verspreidt zich slecht en de luchtkwaliteit is onvoldoende. Stoken veroorzaakt nu veel overlast. In sommige gemeenten kun je een boete krijgen."
        }
    }

    var symbol: String {
        switch self {
        case .yellow: return "flame.fill"
        case .orange: return "exclamationmark.triangle.fill"
        case .red: return "nosign"
        }
    }

    var color: Color {
        switch self {
        case .yellow: return Color(hex: 0xF5B700)
        case .orange: return Color(hex: 0xF27A1A)
        case .red: return Color(hex: 0xE23B3B)
        }
    }

    /// Donkerdere variant voor tekst op een lichte achtergrond (beter contrast).
    var textColor: Color {
        switch self {
        case .yellow: return .dynamic(light: 0x9A6B00, dark: 0xFFCF4A)
        case .orange: return .dynamic(light: 0xB4500A, dark: 0xFF9A4D)
        case .red: return .dynamic(light: 0xB42323, dark: 0xFF6B6B)
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .yellow:
            return LinearGradient(colors: [Color(hex: 0xFFD54A), Color(hex: 0xF2A900)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .orange:
            return LinearGradient(colors: [Color(hex: 0xFFA552), Color(hex: 0xEE6A0E)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .red:
            return LinearGradient(colors: [Color(hex: 0xFF7A6B), Color(hex: 0xD92D2D)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

enum NL {
    static let locale = Locale(identifier: "nl_NL")

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    static func dayTime(_ date: Date) -> String {
        let cal = Calendar.current
        let day: String
        if cal.isDateInToday(date) { day = "Vandaag" }
        else if cal.isDateInTomorrow(date) { day = "Morgen" }
        else { day = date.formatted(.dateTime.weekday(.wide).locale(locale)).capitalized }
        return "\(day) \(time(date))"
    }

    static func weekdayShort(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Vandaag" }
        if cal.isDateInTomorrow(date) { return "Morgen" }
        return date.formatted(.dateTime.weekday(.abbreviated).locale(locale)).capitalized
    }

    static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }
}
