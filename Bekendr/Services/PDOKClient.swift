import Foundation
import CoreLocation

/// Adressen en gebieden zoeken via de PDOK Locatieserver.
struct PDOKClient {
    static let base = URL(string: "https://api.pdok.nl/bzk/locatieserver/search/v3_1")!
    var session: URLSession = .shared

    struct Suggestion: Identifiable, Hashable {
        let id: String
        let label: String
        let type: String
    }

    struct Location: Hashable {
        var id: String
        var label: String
        var type: String
        var name: String
        var latitude: Double
        var longitude: Double
        var municipality: String
        var bounds: KoopClient.Bounds?
        var polygons: [[CLLocationCoordinate2D]]

        static func == (l: Location, r: Location) -> Bool { l.id == r.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    enum PDOKError: LocalizedError {
        case notFound
        var errorDescription: String? { "Deze locatie is niet gevonden." }
    }

    /// Suggesties terwijl je typt. Voor adressen: type "adres"; voor gebieden een van de AreaType-waarden.
    func suggest(_ query: String, types: [String]) async throws -> [Suggestion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        let filter = "type:(" + types.joined(separator: " OR ") + ")"
        let json = try await get("suggest", [
            .init(name: "q", value: q),
            .init(name: "fq", value: filter),
            .init(name: "rows", value: "8"),
        ])
        let docs = ((json["response"] as? [String: Any])?["docs"] as? [[String: Any]]) ?? []
        return docs.compactMap { doc in
            guard let id = doc["id"] as? String, let label = doc["weergavenaam"] as? String else { return nil }
            return Suggestion(id: id, label: label, type: doc["type"] as? String ?? "")
        }
    }

    /// Volledige gegevens van één adres of gebied, met de grens voor gebieden.
    func lookup(_ id: String) async throws -> Location {
        let json = try await get("lookup", [
            .init(name: "id", value: id),
            .init(name: "fl", value: "id,type,weergavenaam,centroide_ll,gemeentenaam,woonplaatsnaam,wijknaam,buurtnaam,geometrie_ll"),
        ])
        let docs = ((json["response"] as? [String: Any])?["docs"] as? [[String: Any]]) ?? []
        guard let doc = docs.first, let point = Self.parsePoint(doc["centroide_ll"] as? String ?? "") else {
            throw PDOKError.notFound
        }
        let type = doc["type"] as? String ?? ""
        let label = doc["weergavenaam"] as? String ?? ""
        let name: String = {
            let key: String
            switch type {
            case "woonplaats": key = "woonplaatsnaam"
            case "wijk": key = "wijknaam"
            case "buurt": key = "buurtnaam"
            case "gemeente": key = "gemeentenaam"
            default: key = ""
            }
            let value = (doc[key] as? String) ?? label
            return value.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? value
        }()
        var polygons: [[CLLocationCoordinate2D]] = []
        var bounds: KoopClient.Bounds?
        if let wkt = doc["geometrie_ll"] as? String, wkt.uppercased().contains("POLYGON") {
            polygons = Self.parsePolygons(wkt)
            let all = polygons.flatMap { $0 }
            if let minLat = all.map(\.latitude).min(), let maxLat = all.map(\.latitude).max(),
               let minLon = all.map(\.longitude).min(), let maxLon = all.map(\.longitude).max() {
                bounds = .init(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
            }
        }
        return Location(id: doc["id"] as? String ?? id, label: label, type: type, name: name,
                        latitude: point.latitude, longitude: point.longitude,
                        municipality: doc["gemeentenaam"] as? String ?? "",
                        bounds: bounds, polygons: polygons)
    }

    /// Dichtstbijzijnde adres bij een coördinaat (voor "Gebruik huidige locatie").
    func reverse(_ coordinate: CLLocationCoordinate2D) async throws -> Location {
        let json = try await get("reverse", [
            .init(name: "lat", value: String(coordinate.latitude)),
            .init(name: "lon", value: String(coordinate.longitude)),
            .init(name: "type", value: "adres"),
            .init(name: "rows", value: "1"),
        ])
        let docs = ((json["response"] as? [String: Any])?["docs"] as? [[String: Any]]) ?? []
        guard let id = docs.first?["id"] as? String else { throw PDOKError.notFound }
        return try await lookup(id)
    }

    private func get(_ path: String, _ items: [URLQueryItem]) async throws -> [String: Any] {
        var components = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = items
        var request = URLRequest(url: components.url!, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        return (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    static func parsePoint(_ wkt: String) -> CLLocationCoordinate2D? {
        let numbers = numbersIn(wkt)
        guard numbers.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: numbers[1], longitude: numbers[0])
    }

    /// Leest de buitenste ring van elk vlak uit een WKT POLYGON of MULTIPOLYGON (lon lat).
    static func parsePolygons(_ wkt: String) -> [[CLLocationCoordinate2D]] {
        var result: [[CLLocationCoordinate2D]] = []
        var depth = 0
        var ringIndex = 0
        var buffer = ""
        let isMulti = wkt.uppercased().hasPrefix("MULTIPOLYGON")
        let ringDepth = isMulti ? 3 : 2
        for ch in wkt {
            switch ch {
            case "(":
                depth += 1
                if depth == ringDepth - 1 { ringIndex = 0 }
                if depth == ringDepth { buffer = "" }
            case ")":
                if depth == ringDepth {
                    if ringIndex == 0 {
                        let nums = numbersIn(buffer)
                        var ring: [CLLocationCoordinate2D] = []
                        var i = 0
                        while i + 1 < nums.count {
                            ring.append(CLLocationCoordinate2D(latitude: nums[i + 1], longitude: nums[i]))
                            i += 2
                        }
                        if ring.count >= 3 { result.append(ring) }
                    }
                    ringIndex += 1
                }
                depth -= 1
            default:
                if depth == ringDepth { buffer.append(ch) }
            }
        }
        return result
    }

    static func contains(_ polygons: [[CLLocationCoordinate2D]], _ p: CLLocationCoordinate2D) -> Bool {
        polygons.contains { ring in
            var inside = false
            var j = ring.count - 1
            for i in 0..<ring.count {
                let a = ring[i], b = ring[j]
                if (a.latitude > p.latitude) != (b.latitude > p.latitude),
                   p.longitude < (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude {
                    inside.toggle()
                }
                j = i
            }
            return inside
        }
    }

    private static func numbersIn(_ text: String) -> [Double] {
        let regex = try! NSRegularExpression(pattern: #"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?"#)
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { Double(ns.substring(with: $0.range)) }
    }
}
