import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Feedback op een bekendmaking, naar het beheer van Bekendr (centrale functie lrbeheer van LRvdLinden).
/// Er gaat geen account of persoonsgegeven mee: alleen de bekendmaking, de reden, je toelichting, het platform,
/// de appversie en een willekeurig apparaatnummer (alleen om misbruik te beperken).
enum FeedbackReason: String, CaseIterable, Identifiable {
    case locatie, categorie, gemeente, link, anders
    var id: String { rawValue }
    var label: String {
        switch self {
        case .locatie: "Locatie klopt niet"
        case .categorie: "Verkeerde categorie"
        case .gemeente: "Verkeerde gemeente"
        case .link: "Link naar de publicatie werkt niet"
        case .anders: "Anders"
        }
    }
    var symbol: String {
        switch self {
        case .locatie: "mappin.slash"
        case .categorie: "square.grid.2x2"
        case .gemeente: "building.2"
        case .link: "link"
        case .anders: "ellipsis.bubble"
        }
    }
}

enum FeedbackClient {
    static let endpoint = URL(string: "https://vbhkewgyujzgbukkbtml.supabase.co/functions/v1/lrbeheer")!

    enum Failure: LocalizedError {
        case tooMany, invalid, network
        var errorDescription: String? {
            switch self {
            case .tooMany: "Je hebt net al een paar keer feedback gestuurd. Probeer het later opnieuw."
            case .invalid: "Vul een toelichting in."
            case .network: "Versturen lukte niet. Controleer je verbinding en probeer het opnieuw."
            }
        }
    }

    static var deviceID: String {
        let key = "feedback.device"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    static var platform: String {
        #if os(macOS)
        return "macos"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipados" : "ios"
        #endif
    }

    static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "\(v) (\(b))"
    }

    static func send(notice: Notice, reason: FeedbackReason, message: String) async throws {
        var req = URLRequest(url: endpoint, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "action": "bekendr_feedback", "notice_id": notice.id, "notice_title": notice.title,
            "notice_url": notice.url.absoluteString, "reason": reason.rawValue, "message": message,
            "platform": platform, "app_version": appVersion, "device": deviceID,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let resp: URLResponse
        do { (_, resp) = try await URLSession.shared.data(for: req) } catch { throw Failure.network }
        switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200..<300: return
        case 429: throw Failure.tooMany
        case 400: throw Failure.invalid
        default: throw Failure.network
        }
    }
}
