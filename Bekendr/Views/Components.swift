import SwiftUI

/// Gekleurd label met icoon voor een categorie.
struct CategoryBadge: View {
    let category: NoticeCategory

    var body: some View {
        Label(category.label, systemImage: category.symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(category.textColor)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(category.tint, in: Capsule())
    }
}

/// Rond kaartpunt in de categoriekleur met een wit icoon.
struct CategoryMarker: View {
    let category: NoticeCategory
    var selected = false

    var body: some View {
        VStack(spacing: -3) {
            Image(systemName: category.symbol)
                .font(.system(size: selected ? 19 : 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: selected ? 44 : 32, height: selected ? 44 : 32)
                .background(category.color, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 2.5))
                .shadow(color: .black.opacity(0.25), radius: selected ? 5 : 3, y: 2)
            if selected {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(category.color)
                    .rotationEffect(.degrees(180))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}

/// Eén melding in een lijst.
struct NoticeRow: View {
    let notice: Notice
    let unread: Bool
    let placeNames: [String: String]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(unread ? Theme.accentFill : .clear)
                .frame(width: 9, height: 9)
                .padding(.top, 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: notice.category.symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(notice.category.color)
                    Text(notice.category.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(notice.category.textColor)
                    Spacer(minLength: 4)
                    Text(Format.day(notice.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(notice.title)
                    .font(.subheadline.weight(unread ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                Text(meta)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel((unread ? "Nieuw. " : "") + "\(notice.category.label). \(notice.title). \(meta)")
    }

    private var meta: String {
        var parts: [String] = []
        if let best = notice.places.min(by: { abs($0.value) < abs($1.value) }), let name = placeNames[best.key] {
            parts.append(best.value >= 0 ? "\(name) · \(Format.distance(best.value))" : name)
        }
        if !notice.creator.isEmpty { parts.append(notice.creator) }
        return parts.joined(separator: " · ")
    }
}
