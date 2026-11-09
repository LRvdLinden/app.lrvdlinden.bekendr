import Foundation

enum Format {
    static let locale = Locale(identifier: "nl_NL")

    static func distance(_ meters: Double) -> String {
        if meters < 0 { return "in het gebied" }
        if meters < 1000 {
            let rounded = meters < 100 ? (meters / 10).rounded() * 10 : (meters / 50).rounded() * 50
            return "\(Int(max(rounded, 10))) m"
        }
        let km = meters / 1000
        return km.formatted(.number.precision(.fractionLength(km < 10 ? 1 : 0)).locale(locale)) + " km"
    }

    static func day(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Vandaag" }
        if cal.isDateInYesterday(date) { return "Gisteren" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }

    static func long(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().locale(locale))
    }

    static func today() -> String {
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale)).capitalized(with: locale)
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }
}
