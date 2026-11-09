import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// Kleur met een variant voor donkere weergave (werkt op iOS, iPadOS en macOS).
    init(light: UInt32, dark: UInt32) {
        func rgb(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
        }
        let (lr, lg, lb) = rgb(light), (dr, dg, db) = rgb(dark)
        #if os(watchOS)
        _ = (lr, lg, lb)
        self.init(red: dr, green: dg, blue: db)
        #elseif canImport(UIKit)
        self.init(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: dr, green: dg, blue: db, alpha: 1)
            : UIColor(red: lr, green: lg, blue: lb, alpha: 1) })
        #else
        self.init(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: dr, green: dg, blue: db, alpha: 1)
                : NSColor(red: lr, green: lg, blue: lb, alpha: 1)
        })
        #endif
    }

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Huisstijl van Bekendr.
enum Theme {
    static let accent = Color(light: 0x2747E8, dark: 0x8A9DFF)
    static let accentFill = Color(hex: 0x2747E8)
    static let accentSoft = Color(light: 0xE4E9FD, dark: 0x1D2547)
    static let ink = Color(light: 0x121726, dark: 0xE9ECF4)
    static let muted = Color(light: 0x5B6275, dark: 0x9AA2B8)
    static let card = Color(light: 0xFFFFFF, dark: 0x1A1F2C)
    static let background = Color(light: 0xF4F5F8, dark: 0x0E111A)
    static let line = Color(light: 0xE3E5EC, dark: 0x2A3040)
    static let home = Color(hex: 0x121726)
}
