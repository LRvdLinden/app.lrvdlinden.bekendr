import Foundation
import CoreLocation

/// Vraagt één keer de huidige locatie op (alleen tijdens gebruik).
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    enum LocationError: LocalizedError {
        case denied, failed
        var errorDescription: String? {
            switch self {
            case .denied: "Bekendr heeft geen toegang tot je locatie. Je kunt dit aanzetten in Instellingen, of zelf een adres zoeken."
            case .failed: "Je locatie kon niet worden bepaald. Probeer het opnieuw of zoek een adres."
            }
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func current() async throws -> CLLocationCoordinate2D {
        switch manager.authorizationStatus {
        case .denied, .restricted: throw LocationError.denied
        default: break
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation?.resume(throwing: LocationError.failed)
            self.continuation = continuation
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.continuation != nil else { return }
            switch self.manager.authorizationStatus {
            case .denied, .restricted:
                self.continuation?.resume(throwing: LocationError.denied)
                self.continuation = nil
            case .notDetermined:
                break
            default:
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.continuation?.resume(returning: coordinate)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: LocationError.failed)
            self.continuation = nil
        }
    }
}
