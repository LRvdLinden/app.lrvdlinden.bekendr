import Foundation
import Observation
import UIKit
import UserNotifications

/// Instellingen voor de meldingsserver (Cloudflare Worker, zie server/worker).
enum PushConfig {
    /// URL van je gedeployde Worker, bijvoorbeeld https://stookwijzer-push.<jouw-subdomein>.workers.dev
    static let serverURL = URL(string: "https://stookwijzer-push.example.workers.dev")!

    /// Moet gelijk zijn aan het APP_KEY-secret van de Worker. Leeg laten als je geen APP_KEY gebruikt.
    static let appKey = ""

    /// Debug-builds praten met de APNs-sandbox, TestFlight en App Store met productie.
    static var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}

/// Regelt toestemming, het APNs device-token en het aan- of afmelden bij de Worker.
@MainActor
@Observable
final class PushManager {
    static let shared = PushManager()

    private(set) var isEnabled: Bool
    var threshold: AdviceCode {
        didSet { UserDefaults.standard.set(threshold.rawValue, forKey: Keys.threshold) }
    }
    var notifyAllClear: Bool {
        didSet { UserDefaults.standard.set(notifyAllClear, forKey: Keys.allClear) }
    }

    private(set) var authorizationDenied = false
    private(set) var isSyncing = false
    private(set) var lastError: String?
    private(set) var lastSynced: Date?

    /// Gezet als de gebruiker op een melding tikt; ContentView selecteert dan die plaats.
    var openedPlaceID: UUID?

    @ObservationIgnored private var deviceToken: String?
    @ObservationIgnored private var places: [Place] = []
    @ObservationIgnored private var lastPayloadHash: Int?

    private enum Keys {
        static let enabled = "push.enabled"
        static let threshold = "push.threshold"
        static let allClear = "push.allClear"
    }

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: Keys.enabled)
        threshold = AdviceCode(rawValue: defaults.object(forKey: Keys.threshold) as? Int ?? 1) ?? .orange
        notifyAllClear = defaults.object(forKey: Keys.allClear) as? Bool ?? true
    }

    // MARK: - Aan/uit

    func setEnabled(_ enabled: Bool) async {
        lastError = nil
        if enabled {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else {
                authorizationDenied = true
                isEnabled = false
                UserDefaults.standard.set(false, forKey: Keys.enabled)
                return
            }
            authorizationDenied = false
            isEnabled = true
            UserDefaults.standard.set(true, forKey: Keys.enabled)
            UIApplication.shared.registerForRemoteNotifications()
        } else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Keys.enabled)
            await unregister()
        }
    }

    /// Bij elke start opnieuw registreren: Apple raadt aan het token steeds te verversen.
    func refreshRegistration() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationDenied = settings.authorizationStatus == .denied
        guard isEnabled else { return }
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        } else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Keys.enabled)
        }
    }

    // MARK: - Token en plaatsen

    func didRegister(token: Data) async {
        deviceToken = token.map { String(format: "%02x", $0) }.joined()
        await sync()
    }

    func didFailToRegister(_ error: Error) {
        lastError = "Aanmelden bij Apple mislukt: \(error.localizedDescription)"
    }

    func update(places: [Place]) async {
        self.places = places
        await sync()
    }

    /// Instellingen gewijzigd: opnieuw doorsturen.
    func settingsChanged() {
        Task { await sync(force: true) }
    }

    // MARK: - Server

    private struct Registration: Encodable {
        struct WatchedPlace: Encodable {
            let id: String
            let name: String
            let lat: Double
            let lon: Double
        }
        let token: String
        let environment: String
        let minCode: Int
        let notifyAllClear: Bool
        let places: [WatchedPlace]
        let appVersion: String
    }

    private func sync(force: Bool = false) async {
        guard isEnabled, let token = deviceToken else { return }

        // Afronden op 2 decimalen (~1 km): genoeg voor de Stookwijzer, beter voor je privacy.
        func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

        let body = Registration(
            token: token,
            environment: PushConfig.environment,
            minCode: threshold.rawValue,
            notifyAllClear: notifyAllClear,
            places: places.map {
                .init(id: $0.id.uuidString, name: $0.name, lat: round2($0.latitude), lon: round2($0.longitude))
            },
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        )

        guard let data = try? JSONEncoder().encode(body) else { return }
        let hash = data.hashValue
        if !force, hash == lastPayloadHash { return }

        isSyncing = true
        defer { isSyncing = false }
        do {
            try await send(path: "register", method: "POST", body: data)
            lastPayloadHash = hash
            lastSynced = Date()
            lastError = nil
        } catch {
            lastError = "Meldingsserver niet bereikbaar. Probeer het later opnieuw."
        }
    }

    private func unregister() async {
        guard let token = deviceToken,
              let data = try? JSONEncoder().encode(["token": token]) else { return }
        try? await send(path: "register", method: "DELETE", body: data)
        lastPayloadHash = nil
        UIApplication.shared.unregisterForRemoteNotifications()
    }

    private func send(path: String, method: String, body: Data) async throws {
        var request = URLRequest(url: PushConfig.serverURL.appendingPathComponent(path), timeoutInterval: 15)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !PushConfig.appKey.isEmpty {
            request.setValue(PushConfig.appKey, forHTTPHeaderField: "X-App-Key")
        }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

/// Ontvangt het APNs-token en toont meldingen ook als de app open staat.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in await PushManager.shared.refreshRegistration() }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await PushManager.shared.didRegister(token: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in PushManager.shared.didFailToRegister(error) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if let raw = info["placeId"] as? String, let id = UUID(uuidString: raw) {
            await MainActor.run { PushManager.shared.openedPlaceID = id }
        }
    }
}
