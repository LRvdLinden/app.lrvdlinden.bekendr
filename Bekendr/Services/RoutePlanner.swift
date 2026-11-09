import Foundation
import MapKit

/// Een gevolgde route: punten (vertrek, tussenstops, bestemming) en de berekende lijn.
struct RouteInfo: Codable, Hashable {
    struct Stop: Codable, Hashable {
        var name: String
        var label: String
        var latitude: Double
        var longitude: Double
        var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    }

    var stops: [Stop]
    /// De lijn als [lat, lon]-paren, vereenvoudigd tot hooguit ~400 punten.
    var points: [[Double]]
    var transport: RouteTransport
    var distance: Double
    var duration: Double

    var coordinates: [CLLocationCoordinate2D] { points.compactMap { $0.count == 2 ? .init(latitude: $0[0], longitude: $0[1]) : nil } }
    var title: String { [stops.first?.name, stops.last?.name].compactMap { $0 }.joined(separator: " → ") }

    var bounds: KoopClient.Bounds? {
        let c = coordinates
        guard let minLat = c.map(\.latitude).min(), let maxLat = c.map(\.latitude).max(),
              let minLon = c.map(\.longitude).min(), let maxLon = c.map(\.longitude).max() else { return nil }
        return .init(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }

    /// Kleinste afstand in meters van een punt tot de route.
    func distance(to point: CLLocationCoordinate2D) -> Double {
        RouteGeometry.distance(point, to: coordinates)
    }

    /// Rechthoeken langs de route (stukken van ~6 km, met een marge), voor de zoekvraag aan KOOP.
    func searchBoxes(margin: Double) -> [KoopClient.Bounds] {
        let c = coordinates
        guard c.count > 1 else { return [] }
        var boxes: [KoopClient.Bounds] = []
        var chunk: [CLLocationCoordinate2D] = [c[0]]
        var length = 0.0
        for i in 1..<c.count {
            length += RouteGeometry.meters(c[i - 1], c[i])
            chunk.append(c[i])
            if length > 6000 || i == c.count - 1 {
                let dLat = margin / 111_000
                let dLon = margin / (111_000 * cos(chunk[0].latitude * .pi / 180))
                boxes.append(.init(minLat: chunk.map(\.latitude).min()! - dLat, maxLat: chunk.map(\.latitude).max()! + dLat,
                                   minLon: chunk.map(\.longitude).min()! - dLon, maxLon: chunk.map(\.longitude).max()! + dLon))
                chunk = [c[i]]
                length = 0
            }
        }
        return boxes
    }
}

enum RouteTransport: String, Codable, CaseIterable, Identifiable {
    case auto, fiets
    var id: String { rawValue }
    var label: String { self == .auto ? "Auto" : "Fiets of lopen" }
    var symbol: String { self == .auto ? "car" : "bicycle" }
    var mapKit: MKDirectionsTransportType { self == .auto ? .automobile : .walking }
}

enum RouteGeometry {
    static func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Afstand van een punt tot een lijn, in een vlakke projectie rond het punt (nauwkeurig genoeg op deze schaal).
    static func distance(_ p: CLLocationCoordinate2D, to line: [CLLocationCoordinate2D]) -> Double {
        guard !line.isEmpty else { return .infinity }
        let kx = 111_320 * cos(p.latitude * .pi / 180), ky = 110_540.0
        func xy(_ c: CLLocationCoordinate2D) -> (Double, Double) { ((c.longitude - p.longitude) * kx, (c.latitude - p.latitude) * ky) }
        if line.count == 1 { let a = xy(line[0]); return hypot(a.0, a.1) }
        var best = Double.infinity
        for i in 1..<line.count {
            let a = xy(line[i - 1]), b = xy(line[i])
            let dx = b.0 - a.0, dy = b.1 - a.1
            let len2 = dx * dx + dy * dy
            let t = len2 == 0 ? 0 : max(0, min(1, -(a.0 * dx + a.1 * dy) / len2))
            best = min(best, hypot(a.0 + t * dx, a.1 + t * dy))
        }
        return best
    }

    /// Houdt punten die minstens `step` meter uit elkaar liggen, en hooguit `max` punten.
    static func simplify(_ c: [CLLocationCoordinate2D], step: Double = 60, max: Int = 400) -> [CLLocationCoordinate2D] {
        guard c.count > 2 else { return c }
        var out = [c[0]]
        for p in c.dropFirst().dropLast() where meters(out.last!, p) >= step { out.append(p) }
        out.append(c.last!)
        if out.count > max {
            let n = Int((Double(out.count) / Double(max)).rounded(.up))
            out = out.enumerated().filter { $0.offset % n == 0 || $0.offset == out.count - 1 }.map(\.element)
        }
        return out
    }
}

enum RoutePlanner {
    enum Failure: LocalizedError {
        case noRoute
        var errorDescription: String? { "Geen route gevonden. Probeer andere punten of een ander vervoer." }
    }

    /// Berekent de route langs alle punten met Apple Kaarten.
    static func plan(stops: [RouteInfo.Stop], transport: RouteTransport) async throws -> RouteInfo {
        guard stops.count >= 2 else { throw Failure.noRoute }
        var line: [CLLocationCoordinate2D] = []
        var distance = 0.0, duration = 0.0
        for i in 1..<stops.count {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: stops[i - 1].coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: stops[i].coordinate))
            request.transportType = transport.mapKit
            guard let route = try await MKDirections(request: request).calculate().routes.first else { throw Failure.noRoute }
            let poly = route.polyline
            var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: poly.pointCount)
            poly.getCoordinates(&coords, range: NSRange(location: 0, length: poly.pointCount))
            line += line.isEmpty ? coords : Array(coords.dropFirst())
            distance += route.distance
            duration += route.expectedTravelTime
        }
        let simple = RouteGeometry.simplify(line)
        return RouteInfo(stops: stops, points: simple.map { [($0.latitude * 1e5).rounded() / 1e5, ($0.longitude * 1e5).rounded() / 1e5] },
                         transport: transport, distance: distance, duration: duration)
    }
}
