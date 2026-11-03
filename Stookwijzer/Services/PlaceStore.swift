import CoreLocation
import Observation
import WidgetKit

@MainActor
@Observable
final class PlaceStore {
    private(set) var current: Place?
    private(set) var saved: [Place]
    var selectedID: UUID? {
        didSet { persistSelection() }
    }
    var locationError: String?

    private static let selectedKey = "selectedPlaceID"

    var all: [Place] { (current.map { [$0] } ?? []) + saved }

    var selected: Place? {
        all.first { $0.id == selectedID } ?? all.first
    }

    init() {
        saved = SharedStore.loadSavedPlaces()
        if let raw = SharedStore.defaults.string(forKey: Self.selectedKey) {
            selectedID = UUID(uuidString: raw)
        }
        // Huidige locatie uit vorige sessie tonen tot er een verse fix is.
        if let last = SharedStore.loadSelected(), last.isCurrentLocation {
            current = last
        }
    }

    func add(_ place: Place) {
        if !saved.contains(where: { $0.name == place.name && $0.subtitle == place.subtitle }) {
            saved.append(place)
            SharedStore.saveSavedPlaces(saved)
        }
        selectedID = saved.first(where: { $0.name == place.name && $0.subtitle == place.subtitle })?.id
    }

    func remove(_ place: Place) {
        saved.removeAll { $0.id == place.id }
        SharedStore.saveSavedPlaces(saved)
        if selectedID == place.id { selectedID = all.first?.id }
    }

    func move(from source: IndexSet, to destination: Int) {
        saved.move(fromOffsets: source, toOffset: destination)
        SharedStore.saveSavedPlaces(saved)
    }

    /// Vraagt de huidige locatie op en zet die bovenaan de lijst.
    func refreshCurrentLocation(using manager: LocationManager) async {
        do {
            let location = try await manager.requestLocation()
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            current = Place(
                id: Place.currentLocationID,
                name: placemark?.locality ?? "Mijn locatie",
                subtitle: "Huidige locatie",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            locationError = nil
            if selectedID == nil || selectedID == Place.currentLocationID {
                selectedID = Place.currentLocationID
            }
            persistSelection()
        } catch {
            locationError = error.localizedDescription
        }
    }

    private func persistSelection() {
        SharedStore.defaults.set(selectedID?.uuidString, forKey: Self.selectedKey)
        SharedStore.saveSelected(selected)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
