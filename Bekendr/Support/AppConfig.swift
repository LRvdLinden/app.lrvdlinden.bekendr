import SwiftUI
import Observation

enum AppConfig {
    static let privacyURL = URL(string: "https://github.com/LRvdLinden/app.lrvdlinden.bekendr/blob/main/PRIVACY.md")!
    static let supportURL = URL(string: "https://github.com/LRvdLinden/app.lrvdlinden.bekendr/issues")!
    static let sourceURL = URL(string: "https://www.officielebekendmakingen.nl")!
    static let refreshTaskID = "app.lrvdlinden.bekendr.refresh"
}

enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "Automatisch"
        case .light: "Licht"
        case .dark: "Donker"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppTab: Hashable {
    case home, inbox, settings
}

/// Navigatie van buitenaf: meldingen, widget, deep links en de deel-extensie.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var tab: AppTab = .home
    var openNoticeID: String?
    var inboxPlaceKey: String?
    var inboxCategory: NoticeCategory?
    var pendingAddress: String?

    func open(url: URL) {
        guard url.scheme == "bekendr" else { return }
        switch url.host {
        case "notice":
            let id = url.pathComponents.dropFirst().joined(separator: "/").removingPercentEncoding ?? ""
            tab = .inbox
            openNoticeID = id.isEmpty ? nil : id
        case "inbox":
            tab = .inbox
        case "add":
            pendingAddress = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "q" }?.value ?? ""
        default:
            tab = .home
        }
    }

    static func noticeURL(_ id: String) -> URL {
        URL(string: "bekendr://notice/" + (id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id))!
    }
}

extension View {
    /// Groot titelformaat op iOS; op de Mac doet dit niets.
    @ViewBuilder
    func largeTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }

    @ViewBuilder
    func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func groupedList() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        listStyle(.inset)
        #endif
    }
}
