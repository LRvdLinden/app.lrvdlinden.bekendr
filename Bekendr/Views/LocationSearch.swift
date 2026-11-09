import SwiftUI
import CoreLocation

/// Werkversie van een locatie tijdens het toevoegen of bewerken.
struct PlaceDraft: Equatable {
    var name = "Thuis"
    var symbol = "house"
    var mode: PlaceMode = .radius
    /// Adres (straal) of, bij één gebied, dat gebied.
    var location: PDOKClient.Location?
    /// Samengevoegde gebieden in de modus "Wijk of gemeente".
    var areas: [PDOKClient.Location] = []
    var radius: Double = 500
    var categories = Set(NoticeCategory.allCases)
    /// Punten van een route: vertrek, tussenstops, bestemming (alleen Apple).
    var routeStops: [PDOKClient.Location] = []
    var transport: RouteTransport = .auto
    var route: RouteInfo?

    init() {}

    init(_ place: Place) {
        name = place.name
        symbol = place.symbol
        mode = place.mode
        radius = place.radius
        categories = place.categories
        if place.mode == .area {
            areas = place.areas.map(\.location)
        } else if place.mode == .route, let r = place.route {
            route = r
            transport = r.transport
            routeStops = r.stops.map { .init(id: "", label: $0.label, type: "adres", name: $0.name, latitude: $0.latitude,
                                             longitude: $0.longitude, municipality: "", bounds: nil, polygons: []) }
        } else if place.isConfigured {
            var bounds: KoopClient.Bounds?
            if place.maxLatitude > place.minLatitude {
                bounds = .init(minLat: place.minLatitude, maxLat: place.maxLatitude,
                               minLon: place.minLongitude, maxLon: place.maxLongitude)
            }
            location = .init(id: place.pdokID, label: place.address, type: place.areaTypeRaw.isEmpty ? "adres" : place.areaTypeRaw,
                             name: place.shortAddress, latitude: place.latitude, longitude: place.longitude,
                             municipality: place.municipality, bounds: bounds, polygons: [])
        }
    }

    var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, !categories.isEmpty else { return false }
        switch mode {
        case .radius: return location?.type == "adres"
        case .area: return !areas.isEmpty
        case .route: return routeStops.count >= 2 && route != nil
        }
    }

    /// De punten van de route zoals Apple Kaarten ze nodig heeft.
    var routeStopInfo: [RouteInfo.Stop] {
        routeStops.map { .init(name: $0.name, label: $0.label, latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// Wat er op het kaartje komt.
    var previewLocations: [PDOKClient.Location] {
        switch mode {
        case .area: areas
        case .route: routeStops
        case .radius: location.map { [$0] } ?? []
        }
    }

    mutating func addArea(_ area: PDOKClient.Location) {
        guard !areas.contains(where: { $0.id == area.id }) else { return }
        areas.append(area)
    }

    func apply(to place: Place) {
        place.name = name.trimmingCharacters(in: .whitespaces)
        place.symbol = symbol
        place.mode = mode
        place.radius = radius
        place.categories = categories
        switch mode {
        case .radius:
            guard let location else { return }
            place.address = location.label
            place.pdokID = location.id
            place.latitude = location.latitude
            place.longitude = location.longitude
            place.municipality = location.municipality
            place.areaTypeRaw = ""
            place.areas = []
            place.minLatitude = 0; place.maxLatitude = 0; place.minLongitude = 0; place.maxLongitude = 0
            place.route = nil
        case .route:
            guard let route, let first = routeStops.first else { return }
            place.route = route
            place.areas = []
            place.address = route.title
            place.pdokID = ""
            place.areaTypeRaw = ""
            place.municipality = first.municipality
            place.latitude = first.latitude
            place.longitude = first.longitude
            if let b = route.bounds {
                place.minLatitude = b.minLat; place.maxLatitude = b.maxLat; place.minLongitude = b.minLon; place.maxLongitude = b.maxLon
            }
        case .area:
            place.route = nil
            guard let first = areas.first else { return }
            place.areas = areas.map(AreaRef.init)
            place.address = areas.map(\.name).joined(separator: " + ")
            place.pdokID = first.id
            place.areaTypeRaw = first.type
            place.municipality = first.municipality
            // Midden en omtrek van alle gebieden samen.
            let bounds = areas.compactMap(\.bounds)
            if let minLat = bounds.map(\.minLat).min(), let maxLat = bounds.map(\.maxLat).max(),
               let minLon = bounds.map(\.minLon).min(), let maxLon = bounds.map(\.maxLon).max() {
                place.minLatitude = minLat; place.maxLatitude = maxLat
                place.minLongitude = minLon; place.maxLongitude = maxLon
                place.latitude = (minLat + maxLat) / 2
                place.longitude = (minLon + maxLon) / 2
            } else {
                place.latitude = areas.map(\.latitude).reduce(0, +) / Double(areas.count)
                place.longitude = areas.map(\.longitude).reduce(0, +) / Double(areas.count)
                place.minLatitude = 0; place.maxLatitude = 0; place.minLongitude = 0; place.maxLongitude = 0
            }
        }
    }

    static let symbols: [(symbol: String, label: String)] = [
        ("house", "Thuis"), ("briefcase", "Werk"), ("heart", "Familie"), ("car", "Route"), ("mappin", "Overig"),
    ]
}

/// Zoekveld voor een adres of gebied, met suggesties van PDOK.
struct LocationSearchField: View {
    let mode: PlaceMode
    @Binding var selection: PDOKClient.Location?
    var initialQuery: String = ""
    /// Gezet bij samenvoegen: elke keuze wordt toegevoegd en het zoekveld wordt weer leeg.
    var onPick: ((PDOKClient.Location) -> Void)? = nil
    var placeholder: String? = nil

    @State private var query = ""
    @State private var suggestions: [PDOKClient.Suggestion] = []
    @State private var isSearching = false
    @State private var message: String?
    @State private var locator = LocationProviderHolder()

    private let pdok = PDOKClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(placeholder ?? (mode == .radius ? "Zoek een adres" : "Zoek een wijk, buurt, woonplaats of gemeente"), text: $query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    .submitLabel(.search)
                if isSearching { ProgressView().controlSize(.small) }
                if !query.isEmpty {
                    Button { query = ""; suggestions = [] } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Wis zoekopdracht")
                }
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { s in
                        Button { Task { await choose(s) } } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: s.type)).foregroundStyle(Theme.accent).frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.label).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                    if s.type != "adres" {
                                        Text(AreaType(rawValue: s.type)?.label ?? s.type.capitalized)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if s.id != suggestions.last?.id { Divider().padding(.leading, 46) }
                    }
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if mode == .radius {
                Button {
                    Task { await useCurrentLocation() }
                } label: {
                    Label("Gebruik huidige locatie", systemImage: "location.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }

            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .task(id: query) {
            let q = query
            guard q.count >= 2, q != selection?.label else { suggestions = []; return }
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            let types = mode == .radius ? ["adres"] : AreaType.allCases.map(\.rawValue)
            do {
                suggestions = try await pdok.suggest(q, types: types)
                message = suggestions.isEmpty ? "Niets gevonden. Probeer het anders te schrijven." : nil
            } catch {
                message = "Zoeken lukt nu niet. Controleer je verbinding."
            }
        }
        .onAppear {
            if query.isEmpty { query = initialQuery.isEmpty ? (selection?.label ?? "") : initialQuery }
        }
        .onChange(of: selection) { _, new in
            if let new { query = new.label }
        }
        .onChange(of: mode) { _, _ in
            suggestions = []
            if selection == nil { query = "" }
        }
    }

    private func icon(for type: String) -> String {
        switch type {
        case "adres": "mappin.circle"
        case "gemeente": "building.columns"
        case "woonplaats": "building.2"
        default: "square.dashed"
        }
    }

    private func choose(_ s: PDOKClient.Suggestion) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let location = try await pdok.lookup(s.id)
            suggestions = []
            message = nil
            if let onPick {
                onPick(location)
                query = ""
            } else {
                selection = location
                query = location.label
            }
        } catch {
            message = "Deze locatie kon niet worden geladen. Probeer het opnieuw."
        }
    }

    private func useCurrentLocation() async {
        isSearching = true
        defer { isSearching = false }
        do {
            let coordinate = try await locator.provider.current()
            let location = try await pdok.reverse(coordinate)
            selection = location
            query = location.label
            suggestions = []
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
}

/// Houdt de locatieaanvrager vast zolang de view bestaat.
@MainActor
final class LocationProviderHolder {
    lazy var provider = LocationProvider()
}

/// Kies één of meer gebieden die samen één locatie vormen.
struct AreaPicker: View {
    @Binding var areas: [PDOKClient.Location]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !areas.isEmpty {
                VStack(spacing: 0) {
                    ForEach(areas, id: \.id) { area in
                        HStack(spacing: 12) {
                            Image(systemName: area.type == "gemeente" ? "building.columns" : "square.dashed")
                                .foregroundStyle(Theme.accent)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(area.name).foregroundStyle(.primary)
                                Text(AreaType(rawValue: area.type)?.label ?? area.type.capitalized)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Button {
                                withAnimation { areas.removeAll { $0.id == area.id } }
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Haal \(area.name) weg")
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        if area.id != areas.last?.id { Divider().padding(.leading, 46) }
                    }
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            LocationSearchField(mode: .area, selection: .constant(nil),
                                onPick: { area in withAnimation { if !areas.contains(where: { $0.id == area.id }) { areas.append(area) } } },
                                placeholder: areas.isEmpty ? nil : "Voeg nog een buurt, wijk of gemeente toe")
            Text(areas.count > 1
                 ? "Deze \(areas.count) gebieden worden samen één locatie, met één lijst meldingen."
                 : "Je kunt meerdere buurten of wijken kiezen; ze worden samen één locatie.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Route kiezen: vertrekpunt, eventueel tussenstops en de bestemming, met Apple Kaarten.
struct RoutePicker: View {
    @Binding var draft: PlaceDraft
    @State private var planning = false
    @State private var error: String?
    @State private var pick: PDOKClient.Location?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(draft.routeStops.enumerated()), id: \.offset) { i, stop in
                HStack(spacing: 10) {
                    Image(systemName: i == 0 ? "circle.circle" : (i == draft.routeStops.count - 1 ? "flag.checkered" : "smallcircle.filled.circle"))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stop.name)
                        Text(i == 0 ? "Vertrekpunt" : (i == draft.routeStops.count - 1 ? "Bestemming" : "Tussenstop \(i)"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { draft.routeStops.remove(at: i) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Haal \(stop.name) weg")
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if draft.routeStops.count < 6 {
                LocationSearchField(mode: .radius, selection: $pick, onPick: { draft.routeStops.append($0) },
                                    placeholder: draft.routeStops.isEmpty ? "Zoek je vertrekpunt"
                                        : (draft.routeStops.count == 1 ? "Zoek je bestemming" : "Nog een punt toevoegen (wordt de bestemming)"))
            }
            Picker("Vervoer", selection: $draft.transport) {
                ForEach(RouteTransport.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            if planning {
                HStack { ProgressView(); Text("Route berekenen…").foregroundStyle(.secondary) }
            } else if let error {
                Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.red)
            } else if let r = draft.route, draft.routeStops.count >= 2 {
                Label("\(Format.distance(r.distance)) · \(Int((r.duration / 60).rounded())) min", systemImage: draft.transport.symbol)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .task(id: draft.routeStopInfo.map { "\($0.latitude),\($0.longitude)" }.joined() + draft.transport.rawValue) {
            await plan()
        }
    }

    private func plan() async {
        guard draft.routeStops.count >= 2 else { draft.route = nil; return }
        if let r = draft.route, r.stops == draft.routeStopInfo, r.transport == draft.transport { return }
        planning = true
        error = nil
        defer { planning = false }
        do {
            draft.route = try await RoutePlanner.plan(stops: draft.routeStopInfo, transport: draft.transport)
        } catch is CancellationError {
        } catch {
            draft.route = nil
            self.error = error.localizedDescription
        }
    }
}
