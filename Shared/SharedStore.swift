import Foundation

/// Gedeelde opslag tussen app en widget via een App Group.
enum SharedStore {
    static let appGroup = "group.nl.lrvdlinden.stookwijzer"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    private static let selectedPlaceKey = "selectedPlace"
    private static let savedPlacesKey = "savedPlaces"
    private static let cachedAdviceKey = "cachedAdvice"

    // MARK: Geselecteerde plaats (voor de widget)

    static func saveSelected(_ place: Place?) {
        guard let place, let data = try? JSONEncoder().encode(place) else {
            defaults.removeObject(forKey: selectedPlaceKey)
            return
        }
        defaults.set(data, forKey: selectedPlaceKey)
    }

    static func loadSelected() -> Place? {
        guard let data = defaults.data(forKey: selectedPlaceKey) else { return nil }
        return try? JSONDecoder().decode(Place.self, from: data)
    }

    // MARK: Opgeslagen plaatsen

    static func saveSavedPlaces(_ places: [Place]) {
        if let data = try? JSONEncoder().encode(places) {
            defaults.set(data, forKey: savedPlacesKey)
        }
    }

    static func loadSavedPlaces() -> [Place] {
        guard let data = defaults.data(forKey: savedPlacesKey) else { return [] }
        return (try? JSONDecoder().decode([Place].self, from: data)) ?? []
    }

    // MARK: Laatst opgehaald advies (fallback voor de widget)

    static func cacheAdvice(_ advice: StookAdvice, for place: Place) {
        let entry = CachedAdvice(placeID: place.id, advice: advice)
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: cachedAdviceKey)
        }
    }

    static func loadCachedAdvice(for place: Place) -> StookAdvice? {
        guard
            let data = defaults.data(forKey: cachedAdviceKey),
            let entry = try? JSONDecoder().decode(CachedAdvice.self, from: data),
            entry.placeID == place.id
        else { return nil }
        return entry.advice
    }

    private struct CachedAdvice: Codable {
        let placeID: UUID
        let advice: StookAdvice
    }
}
