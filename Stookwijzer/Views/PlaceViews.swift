import MapKit
import SwiftUI

/// Zoek een plaats of adres in Nederland en voeg die toe.
struct PlaceSearchView: View {
    @Environment(PlaceStore.self) private var places
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(results, id: \.self) { item in
                    Button { add(item) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.ember)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title(for: item)).foregroundStyle(Theme.ink)
                                Text(subtitle(for: item))
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                }
            }
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView("Zoek een plaats",
                                           systemImage: "magnifyingglass",
                                           description: Text("Bijvoorbeeld een woonplaats, postcode of adres."))
                } else if results.isEmpty && !isSearching {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Plaats, postcode of adres")
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await search()
            }
            .navigationTitle("Plaats toevoegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { results = []; return }
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = .address
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.2, longitude: 5.3),
            span: MKCoordinateSpan(latitudeDelta: 3.6, longitudeDelta: 3.6)
        )
        let response = try? await MKLocalSearch(request: request).start()
        results = (response?.mapItems ?? []).filter { $0.placemark.isoCountryCode == "NL" }
    }

    private func title(for item: MKMapItem) -> String {
        item.placemark.locality ?? item.name ?? "Onbekende plaats"
    }

    private func subtitle(for item: MKMapItem) -> String {
        let p = item.placemark
        let parts = [item.name != p.locality ? item.name : nil, p.administrativeArea].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    private func add(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let name = item.name ?? title(for: item)
        let place = Place(
            id: UUID(),
            name: name,
            subtitle: item.placemark.locality == name ? item.placemark.administrativeArea : item.placemark.locality,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        places.add(place)
        dismiss()
    }
}

/// Lijst met opgeslagen plaatsen (iPhone).
struct ManagePlacesView: View {
    @Environment(PlaceStore.self) private var places
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(places.saved) { place in
                    PlaceRow(place: place)
                }
                .onDelete { offsets in
                    offsets.map { places.saved[$0] }.forEach(places.remove)
                }
                .onMove(perform: places.move)
            }
            .overlay {
                if places.saved.isEmpty {
                    ContentUnavailableView("Geen plaatsen", systemImage: "mappin.slash")
                }
            }
            .navigationTitle("Plaatsen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }
}
