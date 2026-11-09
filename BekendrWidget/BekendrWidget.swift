import WidgetKit
import SwiftUI

struct BekendrEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct BekendrProvider: TimelineProvider {
    func placeholder(in context: Context) -> BekendrEntry {
        BekendrEntry(date: .now, snapshot: .init(updated: .now, newCount: 3, todayCount: 5, weekCount: 23, placeName: "Thuis", items: [
            .init(id: "1", title: "Omgevingsvergunning aangevraagd: plaatsen dakkapel", category: .permit, date: .now, place: "Thuis"),
            .init(id: "2", title: "Verkeersbesluit: twee parkeerplaatsen voor elektrisch laden", category: .traffic, date: .now, place: "Thuis"),
            .init(id: "3", title: "Kapvergunning verleend: drie eiken in het plantsoen", category: .tree, date: .now, place: "Werk"),
        ]))
    }

    func getSnapshot(in context: Context, completion: @escaping (BekendrEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : BekendrEntry(date: .now, snapshot: SharedStore.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BekendrEntry>) -> Void) {
        let entry = BekendrEntry(date: .now, snapshot: SharedStore.loadSnapshot())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

struct BekendrWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BekendrEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: accessory
        case .systemSmall: small
        default: list
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            Text(entry.snapshot.placeName.isEmpty ? "Bekendr" : entry.snapshot.placeName)
                .font(.caption.weight(.bold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            Text("\(entry.snapshot.newCount)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
            Text(entry.snapshot.newCount == 1 ? "nieuwe bekendmaking" : "nieuwe bekendmakingen")
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            Text("\(entry.snapshot.weekCount) deze week")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "bekendr://inbox"))
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                header
                Text("\(entry.snapshot.newCount) nieuw")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.accentFill, in: Capsule())
            }
            if entry.snapshot.items.isEmpty {
                Spacer()
                Text("Niets nieuws in je buurt")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.snapshot.items.prefix(family == .systemLarge ? 6 : 3), id: \.id) { item in
                    Link(destination: URL(string: "bekendr://notice/" + (item.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""))!) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: item.category.symbol)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(item.category.color, in: Circle())
                            Text(item.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .widgetURL(URL(string: "bekendr://inbox"))
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("\(entry.snapshot.newCount) nieuw", systemImage: "mappin.and.ellipse")
                .font(.headline)
            Text(entry.snapshot.items.first?.title ?? "Niets nieuws in je buurt")
                .font(.caption)
                .lineLimit(2)
        }
        .widgetURL(URL(string: "bekendr://inbox"))
    }
}

struct BekendrWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BekendrWidget", provider: BekendrProvider()) { entry in
            BekendrWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Bekendr")
        .description("Nieuwe bekendmakingen in je buurt.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

@main
struct BekendrWidgetBundle: WidgetBundle {
    var body: some Widget {
        BekendrWidget()
    }
}
