import SwiftUI
import WidgetKit

// MARK: - Timeline

struct StookEntry: TimelineEntry {
    let date: Date
    let placeName: String?
    let advice: StookAdvice?
}

struct StookProvider: TimelineProvider {
    func placeholder(in context: Context) -> StookEntry {
        StookEntry(date: .now, placeName: "Apeldoorn", advice: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (StookEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StookEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            var entries = [entry]

            // Extra entries op de blokgrenzen, zodat de code wisselt zonder netwerk.
            if let advice = entry.advice {
                for slot in advice.forecast where slot.date > .now {
                    entries.append(StookEntry(date: slot.date, placeName: entry.placeName, advice: advice))
                }
            }
            let refresh = Calendar.current.date(byAdding: .minute, value: 60, to: .now) ?? .now
            completion(Timeline(entries: entries, policy: .after(refresh)))
        }
    }

    private func makeEntry() async -> StookEntry {
        guard let place = SharedStore.loadSelected() else {
            return StookEntry(date: .now, placeName: nil, advice: nil)
        }
        if let fresh = try? await StookwijzerAPI.fetch(latitude: place.latitude, longitude: place.longitude) {
            SharedStore.cacheAdvice(fresh, for: place)
            return StookEntry(date: .now, placeName: place.name, advice: fresh)
        }
        return StookEntry(date: .now, placeName: place.name, advice: SharedStore.loadCachedAdvice(for: place))
    }
}

// MARK: - Views

struct StookWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StookEntry

    var body: some View {
        if let advice = entry.advice {
            let code = advice.currentCode(at: entry.date)
            switch family {
            case .accessoryCircular:
                circular(code)
            case .accessoryRectangular:
                rectangular(code)
            case .accessoryInline:
                Label("\(code.title) · \(code.headline)", systemImage: code.symbol)
                    .containerBackground(for: .widget) { Color.clear }
            case .systemMedium:
                medium(advice, code: code)
                    .containerBackground(for: .widget) { code.gradient }
            default:
                small(advice, code: code)
                    .containerBackground(for: .widget) { code.gradient }
            }
        } else {
            VStack(spacing: 8) {
                FlameLogo().frame(width: 30, height: 38)
                Text("Open de app om een locatie te kiezen")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.muted)
            }
            .containerBackground(for: .widget) { Theme.background }
        }
    }

    private func small(_ advice: StookAdvice, code: AdviceCode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: code.symbol)
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Text(entry.placeName ?? "")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .opacity(0.9)
            }
            Spacer()
            Text(code.title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1)
                .opacity(0.9)
            Text(code.headline)
                .font(.system(.title3, design: .rounded).bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let next = advice.nextChange(from: entry.date) {
                Text("\(NL.weekdayShort(next.date)) \(NL.time(next.date)): \(next.code.shortTitle.lowercased())")
                    .font(.caption2.weight(.medium))
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
    }

    private func medium(_ advice: StookAdvice, code: AdviceCode) -> some View {
        HStack(spacing: 14) {
            small(advice, code: code)
                .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                ForEach(advice.upcoming(from: entry.date).dropFirst().prefix(4)) { slot in
                    HStack(spacing: 8) {
                        Circle().fill(.white).frame(width: 22, height: 22)
                            .overlay(Image(systemName: slot.code.symbol)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(slot.code.color))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(NL.weekdayShort(slot.date)) \(NL.time(slot.date))")
                                .font(.caption2.weight(.semibold))
                            Text(slot.code.shortTitle)
                                .font(.caption2)
                                .opacity(0.85)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(10)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func circular(_ code: AdviceCode) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: code.symbol).font(.system(size: 16, weight: .bold))
                Text(code.shortTitle).font(.system(size: 10, weight: .semibold))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private func rectangular(_ code: AdviceCode) -> some View {
        HStack(spacing: 8) {
            Image(systemName: code.symbol).font(.title3.weight(.bold))
            VStack(alignment: .leading, spacing: 0) {
                Text(code.title).font(.headline)
                Text(entry.placeName.map { "\(code.headline) · \($0)" } ?? code.headline)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widget

struct StookwijzerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StookwijzerWidget", provider: StookProvider()) { entry in
            StookWidgetView(entry: entry)
        }
        .configurationDisplayName("Stookwijzer")
        .description("Het actuele stookadvies voor je gekozen locatie.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct StookwijzerWidgetBundle: WidgetBundle {
    var body: some Widget {
        StookwijzerWidget()
    }
}

#Preview(as: .systemMedium) {
    StookwijzerWidget()
} timeline: {
    StookEntry(date: .now, placeName: "Apeldoorn", advice: .preview)
}
