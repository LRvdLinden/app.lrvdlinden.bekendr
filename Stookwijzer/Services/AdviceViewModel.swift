import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class AdviceViewModel {
    enum State {
        case idle
        case loading
        case loaded(StookAdvice)
        case failed(String)
    }

    private(set) var state: State = .idle
    private var cache: [UUID: StookAdvice] = [:]
    private var currentPlaceID: UUID?

    func load(for place: Place, force: Bool = false) async {
        let switched = currentPlaceID != place.id
        currentPlaceID = place.id

        // Verse cache (< 10 min) direct tonen
        if !force, let cached = cache[place.id], Date().timeIntervalSince(cached.fetchedAt) < 600 {
            state = .loaded(cached)
            return
        }

        if switched {
            if let cached = cache[place.id] ?? SharedStore.loadCachedAdvice(for: place) {
                state = .loaded(cached)
            } else {
                state = .loading
            }
        } else if case .loaded = state {
            // Oude data zichtbaar laten tijdens verversen
        } else {
            state = .loading
        }

        do {
            let advice = try await StookwijzerAPI.fetch(latitude: place.latitude, longitude: place.longitude)
            guard currentPlaceID == place.id else { return }
            cache[place.id] = advice
            state = .loaded(advice)
            SharedStore.cacheAdvice(advice, for: place)
            WidgetCenter.shared.reloadAllTimelines()
        } catch is CancellationError {
            return
        } catch {
            guard currentPlaceID == place.id else { return }
            if case .loaded = state { return } // houd oude data bij een netwerkfout
            state = .failed(error.localizedDescription)
        }
    }
}
