import Foundation
import UserNotifications

/// Lokale meldingen bij nieuwe bekendmakingen, met stille uren.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// Wordt gezet als de gebruiker op een melding tikt.
    var onOpenNotice: ((String) -> Void)?

    private var defaults: UserDefaults { .standard }

    var isEnabled: Bool { defaults.bool(forKey: "notify.enabled") }
    var quietEnabled: Bool { defaults.object(forKey: "notify.quiet") as? Bool ?? true }
    var quietStart: Int { defaults.object(forKey: "notify.quietStart") as? Int ?? 22 }
    var quietEnd: Int { defaults.object(forKey: "notify.quietEnd") as? Int ?? 7 }

    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Vraagt toestemming; pas aanroepen als de gebruiker meldingen aanzet.
    func requestPermission() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        defaults.set(granted, forKey: "notify.enabled")
        return granted
    }

    func isQuiet(at date: Date = .now) -> Bool {
        guard quietEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        if quietStart == quietEnd { return false }
        return quietStart < quietEnd ? (hour >= quietStart && hour < quietEnd) : (hour >= quietStart || hour < quietEnd)
    }

    func announce(_ notices: [Notice], places: [PlaceInfo]) async {
        guard isEnabled, !notices.isEmpty else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let names = Dictionary(uniqueKeysWithValues: places.map { ($0.key, $0.name) })
        let quiet = isQuiet()

        let content = UNMutableNotificationContent()
        if notices.count == 1, let notice = notices.first {
            let place = notice.places.keys.compactMap { names[$0] }.first
            content.title = notice.category.label + (place.map { " · \($0)" } ?? "")
            content.body = notice.title
            content.userInfo = ["noticeID": notice.id]
        } else {
            content.title = "\(notices.count) nieuwe bekendmakingen"
            content.body = notices.prefix(3).map { "• \($0.title)" }.joined(separator: "\n")
        }
        content.threadIdentifier = "bekendmakingen"
        if !quiet { content.sound = .default }
        if #available(iOS 15.0, macOS 12.0, *) {
            content.interruptionLevel = quiet ? .passive : .active
        }
        let request = UNNotificationRequest(identifier: "new-\(Int(Date().timeIntervalSince1970))", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.content.userInfo["noticeID"] as? String
        await MainActor.run {
            if let id { self.onOpenNotice?(id) } else { self.onOpenNotice?("") }
        }
    }
}
