import Foundation

/// Stookwijzer-code zoals het RIVM die publiceert (advies_N: 0 = geel, 1 = oranje, 2 = rood).
enum AdviceCode: Int, Codable, CaseIterable, Identifiable {
    case yellow = 0
    case orange = 1
    case red = 2

    var id: Int { rawValue }
}

/// Eén blok in de verwachting.
struct ForecastSlot: Codable, Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let code: AdviceCode
    /// RIVM markeert een blok als 'definitief' zodra het niet meer verandert.
    let isFinal: Bool
}

/// Volledig stookadvies voor één locatie.
struct StookAdvice: Codable, Equatable {
    let forecast: [ForecastSlot]
    let fallbackCode: AdviceCode
    let windMS: Double?
    let windBft: Int?
    let lki: Int?
    let modelRun: Date?
    let fetchedAt: Date

    /// Het blok dat nu geldt (laatste blok dat al begonnen is).
    func currentSlot(at date: Date = .now) -> ForecastSlot? {
        forecast.last(where: { $0.date <= date }) ?? forecast.first
    }

    func currentCode(at date: Date = .now) -> AdviceCode {
        currentSlot(at: date)?.code ?? fallbackCode
    }

    /// Blokken vanaf het huidige blok.
    func upcoming(from date: Date = .now) -> [ForecastSlot] {
        guard let current = currentSlot(at: date) else { return forecast }
        return forecast.filter { $0.date >= current.date }
    }

    /// Eerstvolgend moment waarop de code verandert.
    func nextChange(from date: Date = .now) -> ForecastSlot? {
        let now = currentCode(at: date)
        return forecast.first { $0.date > date && $0.code != now }
    }
}

/// Een opgeslagen plaats (of de huidige locatie).
struct Place: Codable, Identifiable, Hashable {
    static let currentLocationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var id: UUID
    var name: String
    var subtitle: String?
    var latitude: Double
    var longitude: Double

    var isCurrentLocation: Bool { id == Place.currentLocationID }
}

/// Luchtkwaliteitsindex (LKI) 1–11 volgens RIVM.
enum AirQuality {
    static func label(for lki: Int) -> String {
        switch lki {
        case ...3: return "Goed"
        case 4...6: return "Matig"
        case 7...8: return "Onvoldoende"
        case 9...10: return "Slecht"
        default: return "Zeer slecht"
        }
    }
}

extension StookAdvice {
    static var preview: StookAdvice {
        let base = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: .now) / 6 * 6,
                                         minute: 0, second: 0, of: .now) ?? .now
        let codes: [AdviceCode] = [.orange, .orange, .yellow, .yellow, .red, .orange, .yellow, .yellow]
        let slots = codes.enumerated().map { i, c in
            ForecastSlot(date: base.addingTimeInterval(Double(i) * 6 * 3600), code: c, isFinal: i < 2)
        }
        return StookAdvice(forecast: slots, fallbackCode: .orange, windMS: 2.4, windBft: 2,
                           lki: 5, modelRun: base, fetchedAt: .now)
    }
}
