import SwiftUI
import SwiftData
import MapKit

/// Kaartje met de straal, of met alle gebieden van een (samengevoegde) locatie.
struct PlaceMapPreview: View {
    let locations: [PDOKClient.Location]
    let mode: PlaceMode
    let radius: Double
    @State private var polygons: [String: [[CLLocationCoordinate2D]]] = [:]

    var body: some View {
        Map(position: .constant(position), interactionModes: []) {
            if mode == .radius, let center = locations.first?.coordinate {
                MapCircle(center: center, radius: radius)
                    .foregroundStyle(Theme.accentFill.opacity(0.12))
                    .stroke(Theme.accentFill.opacity(0.7), lineWidth: 2)
                Annotation("", coordinate: center) {
                    Circle().fill(Theme.home).frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                }
            } else {
                ForEach(locations, id: \.id) { area in
                    let rings = polygons[area.id] ?? area.polygons
                    ForEach(Array(rings.enumerated()), id: \.offset) { _, ring in
                        MapPolygon(coordinates: ring)
                            .foregroundStyle(Theme.accentFill.opacity(0.12))
                            .stroke(Theme.accentFill.opacity(0.7), lineWidth: 2)
                    }
                    if rings.isEmpty {
                        Marker(area.name, coordinate: area.coordinate).tint(Theme.accentFill)
                    }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel(mode == .radius ? "Kaart met een straal van \(Format.distance(radius))"
                                            : "Kaart van \(locations.map(\.name).joined(separator: ", "))")
        .task(id: locations.map(\.id)) {
            // Grenzen ophalen voor gebieden die zonder grens zijn bewaard.
            guard mode == .area else { return }
            for area in locations where area.polygons.isEmpty && polygons[area.id] == nil && !area.id.isEmpty {
                if let full = try? await PDOKClient().lookup(area.id) { polygons[area.id] = full.polygons }
            }
        }
    }

    private var position: MapCameraPosition {
        if mode == .area {
            let bounds = locations.compactMap(\.bounds)
            if let minLat = bounds.map(\.minLat).min(), let maxLat = bounds.map(\.maxLat).max(),
               let minLon = bounds.map(\.minLon).min(), let maxLon = bounds.map(\.maxLon).max() {
                let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.25, longitudeDelta: (maxLon - minLon) * 1.25)
                return .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                                                                 longitude: (minLon + maxLon) / 2), span: span))
            }
        }
        let center = locations.first?.coordinate ?? CLLocationCoordinate2D(latitude: 52.2, longitude: 5.5)
        let meters = max(radius, 150) * 2.8
        return .region(MKCoordinateRegion(center: center, latitudinalMeters: meters, longitudinalMeters: meters))
    }
}

extension PDOKClient.Location {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

/// Instellingen voor de straal en de categorieën.
struct PlaceOptionsSection: View {
    @Binding var draft: PlaceDraft

    var body: some View {
        if draft.mode == .radius {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Straal")
                        Spacer()
                        Text(Format.distance(draft.radius)).foregroundStyle(Theme.accent).fontWeight(.semibold)
                    }
                    Slider(value: $draft.radius, in: 100...2000, step: 50) {
                        Text("Straal")
                    } minimumValueLabel: {
                        Text("100 m").font(.caption).foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("2 km").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        Section("Categorieën voor deze locatie") {
            ForEach(NoticeCategory.allCases) { category in
                Toggle(isOn: Binding(
                    get: { draft.categories.contains(category) },
                    set: { on in if on { draft.categories.insert(category) } else { draft.categories.remove(category) } })) {
                    Label {
                        Text(category.name)
                    } icon: {
                        Image(systemName: category.symbol).foregroundStyle(category.color)
                    }
                }
            }
        }
    }
}

/// Locatie toevoegen of bewerken.
struct PlaceEditorView: View {
    let place: Place?
    var initialQuery: String = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Place.sortOrder) private var places: [Place]
    @State private var draft = PlaceDraft()
    @State private var loaded = false
    @State private var confirmDelete = false
    @State private var saved = 0

    var body: some View {
        Form {
            Section {
                TextField("Naam", text: $draft.name)
                Picker("Pictogram", selection: $draft.symbol) {
                    ForEach(PlaceDraft.symbols, id: \.symbol) { symbol, label in
                        Label(label, systemImage: symbol).tag(symbol)
                    }
                }
            }

            Section {
                Picker("Soort", selection: $draft.mode) {
                    ForEach(PlaceMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Group {
                    if draft.mode == .area {
                        AreaPicker(areas: $draft.areas)
                    } else {
                        LocationSearchField(mode: .radius, selection: $draft.location, initialQuery: initialQuery)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if draft.isValid {
                    PlaceMapPreview(locations: draft.previewLocations, mode: draft.mode, radius: draft.radius)
                        .listRowInsets(EdgeInsets())
                }
            } footer: {
                if draft.mode == .area {
                    Text("Je krijgt de bekendmakingen binnen alle gekozen gebieden samen, ook die voor een hele gemeente gelden.")
                }
            }

            PlaceOptionsSection(draft: $draft)

            if place != nil {
                Section {
                    Button("Locatie verwijderen", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(place == nil ? "Nieuwe locatie" : "Locatie")
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuleren") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Bewaar") { save() }
                    .disabled(!draft.isValid)
            }
        }
        .confirmationDialog("Locatie verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Verwijder \(place?.name ?? "")", role: .destructive) {
                if let place { context.delete(place); try? context.save() }
                dismiss()
            }
        } message: {
            Text("De locatie en de bijbehorende instellingen worden verwijderd.")
        }
        .sensoryFeedback(.success, trigger: saved)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let place { draft = PlaceDraft(place) } else {
                draft.name = places.isEmpty ? "Thuis" : "Locatie \(places.count + 1)"
                draft.symbol = places.isEmpty ? "house" : "mappin"
            }
        }
        .onChange(of: draft.areas.count) { old, new in
            // Eerste gebied bij een nieuwe locatie: neem de naam over als die nog standaard is.
            if place == nil, old == 0, new > 0, draft.name == "Thuis" || draft.name.hasPrefix("Locatie "),
               let first = draft.areas.first {
                draft.name = first.name
                draft.symbol = "mappin"
            }
        }
        .onChange(of: draft.mode) { _, mode in
            // Alleen wissen als het gekozen adres of gebied niet bij de nieuwe soort past.
            if let type = draft.location?.type, (mode == .radius) != (type == "adres") { draft.location = nil }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 620)
        #endif
    }

    private func save() {
        let target: Place
        if let place {
            target = place
        } else {
            target = Place()
            target.sortOrder = (places.map(\.sortOrder).max() ?? -1) + 1
            context.insert(target)
        }
        draft.apply(to: target)
        try? context.save()
        saved += 1
        dismiss()
    }
}
