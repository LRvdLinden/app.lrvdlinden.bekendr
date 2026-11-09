import Foundation
import LocalAuthentication
import Observation

/// Vergrendeling met Face ID, Touch ID of de toegangscode.
@MainActor
@Observable
final class AppLock {
    static let shared = AppLock()

    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool

    private init() {
        let enabled = UserDefaults.standard.bool(forKey: "lock.enabled")
        isEnabled = enabled
        isLocked = enabled
    }

    /// Naam van de beschikbare methode, bijvoorbeeld "Face ID".
    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "toegangscode"
        }
    }

    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        guard isEnabled else { isLocked = false; return }
        let context = LAContext()
        context.localizedCancelTitle = "Annuleren"
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Ontgrendel Bekendr")
            if ok { isLocked = false }
        } catch {
            // Blijft vergrendeld; de gebruiker kan het opnieuw proberen.
        }
    }

    /// Bij het aanzetten eerst bevestigen, zodat niemand zichzelf buitensluit.
    func setEnabled(_ enabled: Bool) async {
        var ok = false
        if enabled {
            let context = LAContext()
            ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Zet vergrendeling aan")) ?? false
        }
        isEnabled = ok
        isLocked = false
        UserDefaults.standard.set(ok, forKey: "lock.enabled")
    }
}
