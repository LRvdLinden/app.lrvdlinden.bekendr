import Foundation

enum StookwijzerError: LocalizedError {
    case noData
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .noData:
            return "Voor deze locatie is geen stookadvies beschikbaar. De Stookwijzer werkt alleen in Nederland."
        case .badResponse(let code):
            return "De Stookwijzer-dienst gaf een fout (\(code)). Probeer het later opnieuw."
        }
    }
}

/// Haalt het stookadvies op bij de RIVM Atlas Leefomgeving (laag `stookwijzer_v2`).
///
/// Dit is hetzelfde endpoint dat de publieke Stookwijzer-kaart en de Home Assistant-integratie gebruiken.
/// Let op: de `servicekey` is de publieke sleutel van Atlas Leefomgeving. Vraag voor publicatie in de
/// App Store bij het RIVM na of je deze mag gebruiken, of vraag een eigen sleutel aan.
enum StookwijzerAPI {
    private static let baseURL = "https://data.rivm.nl/geo/alo/wms"
    private static let serviceKey = "82b124ad-834d-4c10-8bd0-ee730d5c1cc8"
    private static let layer = "stookwijzer_v2"

    static func fetch(latitude: Double, longitude: Double) async throws -> StookAdvice {
        let rd = RDConverter.toRD(latitude: latitude, longitude: longitude)
        let bbox = String(format: "%.0f,%.0f,%.0f,%.0f", rd.x, rd.y, rd.x + 10, rd.y + 10)

        let query = [
            "SERVICE=WMS", "VERSION=1.3.0", "REQUEST=GetFeatureInfo",
            "FORMAT=image/png", "TRANSPARENT=true",
            "QUERY_LAYERS=\(layer)", "LAYERS=\(layer)",
            "servicekey=\(serviceKey)", "STYLES=", "BUFFER=1",
            "EXCEPTIONS=INIMAGE", "info_format=application/json", "feature_count=1",
            "I=139", "J=222", "WIDTH=256", "HEIGHT=256",
            "CRS=EPSG:28992", "BBOX=\(bbox)",
        ].joined(separator: "&")

        guard let url = URL(string: "\(baseURL)?\(query)") else { throw StookwijzerError.noData }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw StookwijzerError.badResponse(http.statusCode)
        }
        return try parse(data)
    }

    // MARK: - Parsing

    private static let runtimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "dd-MM-yyyy HH:mm"
        return f
    }()

    static func parse(_ data: Data) throws -> StookAdvice {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let features = root["features"] as? [[String: Any]],
            let props = features.first?["properties"] as? [String: Any]
        else { throw StookwijzerError.noData }

        func string(_ key: String) -> String? {
            guard let value = props[key], !(value is NSNull) else { return nil }
            let s = "\(value)".trimmingCharacters(in: .whitespaces)
            return s.isEmpty ? nil : s
        }

        let modelRun = string("model_runtime").flatMap { runtimeFormatter.date(from: $0) }
        let base = modelRun ?? Date()

        // Alle velden advies_0, advies_6, advies_12 … dynamisch uitlezen, zodat extra blokken vanzelf meekomen.
        var slots: [ForecastSlot] = []
        for key in props.keys where key.hasPrefix("advies_") {
            guard
                let offset = Int(key.dropFirst("advies_".count)),
                let raw = string(key),
                let value = Double(raw).map({ Int($0) }),
                let code = AdviceCode(rawValue: value)
            else { continue }

            let finalRaw = string("definitief_\(offset)")?.lowercased()
            slots.append(ForecastSlot(
                date: base.addingTimeInterval(Double(offset) * 3600),
                code: code,
                isFinal: finalRaw == "true" || finalRaw == "1"
            ))
        }
        slots.sort { $0.date < $1.date }

        guard let first = slots.first else { throw StookwijzerError.noData }

        let wind = string("wind").flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
        let bft = string("wind_bft").flatMap { Double($0) }.map { Int($0) }
        let lki = string("lki").flatMap { Double($0) }.map { Int($0) }

        return StookAdvice(
            forecast: slots,
            fallbackCode: first.code,
            windMS: wind.map { ($0 * 10).rounded() / 10 },
            windBft: bft,
            lki: lki,
            modelRun: modelRun,
            fetchedAt: Date()
        )
    }
}
