import Foundation
import Observation

/// De lijst die het laatst getoond is, zodat je in een melding naar de vorige of volgende kunt.
@MainActor
@Observable
final class NoticeNavigator {
    static let shared = NoticeNavigator()
    var sequence: [Notice] = []

    func neighbours(of notice: Notice) -> (previous: Notice?, next: Notice?) {
        guard let i = sequence.firstIndex(where: { $0.id == notice.id }) else { return (nil, nil) }
        return (i > 0 ? sequence[i - 1] : nil, i + 1 < sequence.count ? sequence[i + 1] : nil)
    }

    func position(of notice: Notice) -> (Int, Int)? {
        guard let i = sequence.firstIndex(where: { $0.id == notice.id }) else { return nil }
        return (i + 1, sequence.count)
    }
}
