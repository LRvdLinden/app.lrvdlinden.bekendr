import CoreLocation
import Observation

enum LocationError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Geen toegang tot je locatie. Zet dit aan in Instellingen of voeg handmatig een plaats toe."
    }
}

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var authContinuation: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    var authorization: CLAuthorizationStatus = .notDetermined

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    override init() {
        super.init()
        authorization = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { cont in
                authContinuation = cont
                manager.requestWhenInUseAuthorization()
            }
        }
        guard isAuthorized else { throw LocationError.denied }

        return try await withCheckedThrowingContinuation { cont in
            locationContinuation?.resume(throwing: CancellationError())
            locationContinuation = cont
            manager.requestLocation()
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status != .notDetermined {
                self.authContinuation?.resume()
                self.authContinuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(throwing: error)
            self.locationContinuation = nil
        }
    }
}
