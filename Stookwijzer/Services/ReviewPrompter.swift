import StoreKit
import SwiftUI

/// App Store-reviewvraag: eerste keer 4 uur na eerste gebruik op dit apparaat,
/// daarna hoogstens één keer per week, alleen op een rustig moment.
enum ReviewPrompter {
    private static let firstUseKey = "review.firstUseDate"
    private static let lastAskKey = "review.lastRequestDate"
    static let firstDelay: TimeInterval = 4 * 60 * 60
    static let interval: TimeInterval = 7 * 24 * 60 * 60

    /// Roep aan bij elke start; zet de eerste-gebruiksdatum één keer.
    static func registerUse(now: Date = .now) {
        let d = UserDefaults.standard
        if d.object(forKey: firstUseKey) == nil { d.set(now, forKey: firstUseKey) }
    }

    static func isEligible(now: Date = .now) -> Bool {
        let d = UserDefaults.standard
        guard let first = d.object(forKey: firstUseKey) as? Date,
              now.timeIntervalSince(first) >= firstDelay else { return false }
        if let last = d.object(forKey: lastAskKey) as? Date,
           now.timeIntervalSince(last) < interval { return false }
        return true
    }

    static func markRequested(now: Date = .now) {
        UserDefaults.standard.set(now, forKey: lastAskKey)
    }
}

/// Hang aan de hoofdweergave: .reviewPrompt(isCalm: …)
struct ReviewPromptModifier: ViewModifier {
    let isCalm: Bool
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear { ReviewPrompter.registerUse() }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? schedule() : task?.cancel()
            }
            .onChange(of: isCalm) { _, calm in calm ? schedule() : task?.cancel() }
            .task { schedule() }
    }

    private func schedule() {
        task?.cancel()
        guard isCalm, ReviewPrompter.isEligible() else { return }
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, isCalm, scenePhase == .active,
                  ReviewPrompter.isEligible() else { return }
            ReviewPrompter.markRequested()
            requestReview()
        }
    }
}

extension View {
    func reviewPrompt(isCalm: Bool) -> some View {
        modifier(ReviewPromptModifier(isCalm: isCalm))
    }
}

/// Of het splashscreen nog zichtbaar is (gezet door RootView).
private struct SplashVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var splashVisible: Bool {
        get { self[SplashVisibleKey.self] }
        set { self[SplashVisibleKey.self] = newValue }
    }
}
