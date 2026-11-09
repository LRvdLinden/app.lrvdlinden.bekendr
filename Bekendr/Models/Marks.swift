import Foundation
import SwiftData

/// Snel opzoeken van wat de gebruiker met meldingen deed.
struct MarkIndex {
    let byID: [String: NoticeMark]

    init(_ marks: [NoticeMark]) {
        var dict: [String: NoticeMark] = [:]
        for mark in marks where dict[mark.noticeID] == nil { dict[mark.noticeID] = mark }
        byID = dict
    }

    func isUnread(_ n: Notice) -> Bool { !n.initial && !(byID[n.id]?.isRead ?? false) && !isTrashed(n) }
    func isSaved(_ n: Notice) -> Bool { byID[n.id]?.isSaved ?? false }
    func isTrashed(_ n: Notice) -> Bool { byID[n.id]?.trashedAt != nil }

    /// In de prullenbak en nog geen 30 dagen oud (en niet definitief verwijderd).
    func isInTrash(_ n: Notice) -> Bool {
        guard let date = byID[n.id]?.trashedAt, date != .distantPast else { return false }
        return Date().timeIntervalSince(date) < 30 * 86_400
    }

    /// Bewaarde meldingen, ook als ze niet meer in de recente lijst staan.
    func savedNotices(current: [Notice]) -> [Notice] {
        let currentByID = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return byID.values.filter(\.isSaved).compactMap { mark in
            currentByID[mark.noticeID] ?? mark.savedCopy.flatMap { try? decoder.decode(Notice.self, from: $0) }
        }
        .sorted { $0.date > $1.date }
    }
}

@MainActor
enum MarkActions {
    private static func mark(for id: String, in context: ModelContext) -> NoticeMark {
        let descriptor = FetchDescriptor<NoticeMark>(predicate: #Predicate { $0.noticeID == id })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let mark = NoticeMark(noticeID: id)
        context.insert(mark)
        return mark
    }

    static func setRead(_ notice: Notice, _ read: Bool = true, in context: ModelContext) {
        let m = mark(for: notice.id, in: context)
        guard m.isRead != read else { return }
        m.isRead = read
        m.updatedAt = .now
        try? context.save()
    }

    static func markAllRead(_ notices: [Notice], in context: ModelContext) {
        for n in notices where !n.initial {
            let m = mark(for: n.id, in: context)
            if !m.isRead { m.isRead = true; m.updatedAt = .now }
        }
        try? context.save()
    }

    static func toggleSaved(_ notice: Notice, in context: ModelContext) {
        let m = mark(for: notice.id, in: context)
        m.isSaved.toggle()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        m.savedCopy = m.isSaved ? try? encoder.encode(notice) : nil
        m.updatedAt = .now
        try? context.save()
    }

    static func trash(_ notice: Notice, in context: ModelContext) {
        let m = mark(for: notice.id, in: context)
        m.trashedAt = .now
        m.isRead = true
        m.updatedAt = .now
        try? context.save()
    }

    static func restore(_ notice: Notice, in context: ModelContext) {
        let m = mark(for: notice.id, in: context)
        m.trashedAt = nil
        m.updatedAt = .now
        try? context.save()
    }

    static func deleteForever(_ notice: Notice, in context: ModelContext) {
        let m = mark(for: notice.id, in: context)
        m.trashedAt = .distantPast
        m.isSaved = false
        m.savedCopy = nil
        m.updatedAt = .now
        try? context.save()
    }
}
