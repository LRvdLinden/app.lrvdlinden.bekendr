import Foundation

/// Gedeelde opslag tussen de app, de widget en de deel-extensie (App Group).
enum SharedStore {
    static let appGroup = "group.app.lrvdlinden.bekendr"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    private static var container: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return url
        }
        // Geen App Group beschikbaar (bijvoorbeeld op de Mac): gewone app-map.
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Bekendr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var snapshotURL: URL { container.appendingPathComponent("widget.json") }

    static func saveSnapshot(_ snapshot: WidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: snapshotURL, options: .atomic)
        }
    }

    static func loadSnapshot() -> WidgetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else { return .empty }
        return snapshot
    }

    /// Een adres dat via de deel-extensie binnenkwam en nog als locatie moet worden toegevoegd.
    static var pendingAddress: String? {
        get { defaults.string(forKey: "share.pendingAddress") }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: "share.pendingAddress")
            } else {
                defaults.removeObject(forKey: "share.pendingAddress")
            }
        }
    }
}
