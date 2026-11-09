import Foundation

/// Haalt officiële bekendmakingen op bij KOOP (repository.overheid.nl, SRU 2.0).
struct KoopClient {
    static let base = URL(string: "https://repository.overheid.nl/sru")!
    static let pageSize = 250
    /// KOOP staat geografische vlakken tot ongeveer 350 km² toe; ruim daaronder blijven.
    static let maxTileArea = 230.0

    struct Record: Hashable {
        var identifier = ""
        var title = ""
        var modified = ""
        var creator = ""
        var type = ""
        var subjects: [String] = []
        var spatials: [String] = []
        var summary = ""
        var preferredURL = ""
        var point = ""
        var municipality = ""
    }

    struct Bounds: Hashable {
        var minLat: Double, maxLat: Double, minLon: Double, maxLon: Double
    }

    enum KoopError: LocalizedError {
        case refused(String)
        case invalidResponse
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .refused(let reason): "De bekendmakingen konden niet worden opgehaald: \(reason)"
            case .invalidResponse: "De bekendmakingen-server gaf een onverwacht antwoord."
            case .http(let code): "De bekendmakingen-server is niet bereikbaar (fout \(code))."
            }
        }
    }

    var session: URLSession = .shared

    // MARK: Zoekopdrachten

    static func dateString(daysAgo days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func base(days: Int) -> String {
        "(c.product-area==\"officielepublicaties\" AND dt.modified>=\(dateString(daysAgo: days)))"
    }

    private static func num(_ v: Double) -> String { String(format: "%.7f", v) }

    /// Zoeken rond een punt met een straal in meters.
    static func radiusQuery(lat: Double, lon: Double, radius: Double, days: Int) -> String {
        let geo = "within/etrs89 \"\(num(lat)) \(num(lon)) \(String(format: "%.3f", radius / 1000))\""
        return "\(base(days: days)) AND (w.locatiepunt \(geo) OR cd.afgeleideLocatiegebied \(geo)) sortBy dt.modified /sort.descending"
    }

    /// Zoeken binnen een rechthoek (noord, west, zuid, oost).
    static func boxQuery(_ b: Bounds, days: Int) -> String {
        let geo = "within/nwse.etrs89 \"\(num(b.maxLat)) \(num(b.minLon)) \(num(b.minLat)) \(num(b.maxLon))\""
        return "\(base(days: days)) AND (w.locatiepunt \(geo) OR cd.afgeleideLocatiegebied \(geo)) sortBy dt.modified /sort.descending"
    }

    /// Publicaties van één gemeente (voor bekendmakingen die voor de hele gemeente gelden).
    static func creatorQuery(_ municipality: String, days: Int) -> String? {
        guard let name = quoted(municipality) else { return nil }
        return "\(base(days: days)) AND dt.creator=\(name) sortBy dt.modified /sort.descending"
    }

    /// Publicaties die de naam van het gebied noemen.
    static func nameQuery(_ area: String, days: Int) -> String? {
        guard area.count >= 3, let name = quoted(area) else { return nil }
        return "\(base(days: days)) AND (dt.spatial=\(name) OR dt.title=\(name)) sortBy dt.modified /sort.descending"
    }

    private static func quoted(_ value: String) -> String? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 120, !text.contains("\""), !text.contains("\\") else { return nil }
        return "\"\(text)\""
    }

    /// Deelt een grote rechthoek op in vakken die KOOP accepteert.
    static func tiles(for b: Bounds) -> [Bounds] {
        let latKm = (b.maxLat - b.minLat) * 111.32
        let lonKm = (b.maxLon - b.minLon) * 111.32 * cos(b.minLat * .pi / 180)
        var nLat = 1, nLon = 1
        while latKm * lonKm / Double(nLat * nLon) > maxTileArea && nLat * nLon < 24 {
            if latKm / Double(nLat) >= lonKm / Double(nLon) { nLat += 1 } else { nLon += 1 }
        }
        var result: [Bounds] = []
        for y in 0..<nLat {
            for x in 0..<nLon {
                result.append(Bounds(
                    minLat: b.minLat + (b.maxLat - b.minLat) * Double(y) / Double(nLat),
                    maxLat: b.minLat + (b.maxLat - b.minLat) * Double(y + 1) / Double(nLat),
                    minLon: b.minLon + (b.maxLon - b.minLon) * Double(x) / Double(nLon),
                    maxLon: b.minLon + (b.maxLon - b.minLon) * Double(x + 1) / Double(nLon)))
            }
        }
        return result
    }

    // MARK: Ophalen

    func fetch(query: String, maxPages: Int = 2) async throws -> [Record] {
        var records: [Record] = []
        for page in 0..<maxPages {
            var components = URLComponents(url: Self.base, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                .init(name: "version", value: "2.0"),
                .init(name: "operation", value: "searchRetrieve"),
                .init(name: "query", value: query),
                .init(name: "startRecord", value: String(page * Self.pageSize + 1)),
                .init(name: "maximumRecords", value: String(Self.pageSize)),
                .init(name: "recordSchema", value: "gzd"),
            ]
            // '+' en '=' in de zoekvraag moeten letterlijk aankomen.
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
            var request = URLRequest(url: components.url!, timeoutInterval: 30)
            request.setValue("application/xml", forHTTPHeaderField: "Accept")
            request.setValue("Bekendr/1.0 (app.lrvdlinden.bekendr)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw KoopError.http(http.statusCode)
            }
            let parsed = try KoopParser.parse(data)
            records.append(contentsOf: parsed.records)
            if records.count >= parsed.total || parsed.records.count < Self.pageSize { break }
        }
        return records
    }

    // MARK: Omzetten

    static func notice(from r: Record, firstSeen: Date = .now) -> Notice? {
        let id = r.identifier.isEmpty ? r.preferredURL : r.identifier
        guard !id.isEmpty else { return nil }
        let title = r.title.isEmpty ? "Officiële bekendmaking" : r.title
        let point = parsePoint(r.point)
        let subject = r.subjects.joined(separator: " · ")
        return Notice(
            id: id,
            title: title,
            date: parseDate(r.modified) ?? firstSeen,
            creator: r.creator,
            type: r.type,
            subject: subject,
            spatial: r.spatials.joined(separator: " · "),
            summary: r.summary,
            url: officialURL(identifier: r.identifier, preferred: r.preferredURL),
            latitude: point?.lat,
            longitude: point?.lon,
            category: NoticeCategory.classify([title, r.type, subject, r.summary]),
            places: [:],
            firstSeen: firstSeen,
            initial: false)
    }

    static func officialURL(identifier: String, preferred: String) -> URL {
        if preferred.lowercased().hasPrefix("http"), let url = URL(string: preferred) { return url }
        if let range = identifier.range(of: #"[a-z]+-\d{4}-\d+"#, options: [.regularExpression, .caseInsensitive]),
           let url = URL(string: "https://zoek.officielebekendmakingen.nl/\(identifier[range]).html") {
            return url
        }
        if identifier.lowercased().hasPrefix("http"), let url = URL(string: identifier) { return url }
        return URL(string: "https://zoek.officielebekendmakingen.nl/")!
    }

    static func parseDate(_ text: String) -> Date? {
        let value = text.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: value) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let d = f.date(from: String(value.prefix(format == "yyyy-MM-dd" ? 10 : 19))) { return d }
        }
        return nil
    }

    /// Leest een locatiepunt: "POINT(lon lat)" of twee getallen in breedte/lengte (in welke volgorde dan ook).
    static func parsePoint(_ text: String) -> (lat: Double, lon: Double)? {
        let regex = try! NSRegularExpression(pattern: #"-?\d+(?:\.\d+)?"#)
        let ns = text as NSString
        let numbers = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { Double(ns.substring(with: $0.range)) }
        guard numbers.count >= 2 else { return nil }
        let a = numbers[0], b = numbers[1]
        let isLat: (Double) -> Bool = { (50.0...54.0).contains($0) }
        let isLon: (Double) -> Bool = { (2.5...8.0).contains($0) }
        if text.uppercased().contains("POINT"), isLon(a), isLat(b) { return (b, a) }
        if isLat(a), isLon(b) { return (a, b) }
        if isLon(a), isLat(b) { return (b, a) }
        return nil
    }
}

/// Eenvoudige SRU-lezer: verzamelt per record de velden die Bekendr gebruikt.
final class KoopParser: NSObject, XMLParserDelegate {
    private(set) var records: [KoopClient.Record] = []
    private(set) var total = 0
    private var current: KoopClient.Record?
    private var text = ""
    private var diagnostic: String?
    private var inDiagnostics = false
    private var depthInRecord = 0

    static func parse(_ data: Data) throws -> (records: [KoopClient.Record], total: Int) {
        let delegate = KoopParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        guard parser.parse() else { throw KoopClient.KoopError.invalidResponse }
        if let reason = delegate.diagnostic { throw KoopClient.KoopError.refused(reason) }
        return (delegate.records, delegate.total)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = local(elementName)
        text = ""
        if name == "diagnostics" { inDiagnostics = true }
        if name == "record" {
            depthInRecord += 1
            if depthInRecord == 1 { current = KoopClient.Record() }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = local(elementName)
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { text = "" }

        if inDiagnostics {
            if (name == "message" || name == "details"), diagnostic == nil, !value.isEmpty {
                diagnostic = String(value.prefix(180))
            }
            if name == "diagnostics" { inDiagnostics = false }
            return
        }
        if name == "numberOfRecords", current == nil { total = Int(value) ?? 0; return }
        if name == "record" {
            depthInRecord -= 1
            if depthInRecord == 0, let record = current {
                if !record.identifier.isEmpty || !record.title.isEmpty { records.append(record) }
                current = nil
            }
            return
        }
        guard current != nil, !value.isEmpty else { return }
        switch name {
        case "identifier": if current!.identifier.isEmpty { current!.identifier = value }
        case "title": if current!.title.isEmpty { current!.title = value }
        case "modified": if current!.modified.isEmpty { current!.modified = value }
        case "issued", "available", "date": if current!.modified.isEmpty { current!.modified = value }
        case "creator", "authority": if current!.creator.isEmpty { current!.creator = value }
        case "type": if current!.type.isEmpty { current!.type = value }
        case "subject": current!.subjects.append(value)
        case "spatial": current!.spatials.append(value)
        case "abstract", "description": if current!.summary.isEmpty { current!.summary = value }
        case "preferredUrl", "prefferedUrl": if current!.preferredURL.isEmpty { current!.preferredURL = value }
        case "locatiepunt": if current!.point.isEmpty { current!.point = value }
        case "gemeentenaam": if current!.municipality.isEmpty { current!.municipality = value }
        default: break
        }
    }

    private func local(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }
}
