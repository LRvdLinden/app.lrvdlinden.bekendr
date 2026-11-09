import SwiftUI
import SwiftData
import MapKit

/// Eén bekendmaking met de gegevens, een kaartje en de link naar de officiële publicatie.
struct NoticeDetailView: View {
    private let start: Notice
    @State private var current: Notice?
    @State private var showFeedback = false
    @State private var lookAround: MKLookAroundScene?
    @State private var navigator = NoticeNavigator.shared
    private var notice: Notice { current ?? start }

    init(notice: Notice) { start = notice }
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \Place.sortOrder) private var places: [Place]
    @Query private var marks: [NoticeMark]
    @State private var savedTick = 0

    private var index: MarkIndex { MarkIndex(marks) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    CategoryBadge(category: notice.category)
                    if !notice.type.isEmpty {
                        Text(notice.type.capitalized(with: Format.locale))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.card, in: Capsule())
                            .lineLimit(1)
                    }
                }

                Text(notice.title)
                    .font(.title2.weight(.heavy))
                    .textSelection(.enabled)

                VStack(spacing: 0) {
                    if !notice.creator.isEmpty { row("Instantie", notice.creator) }
                    row("Gepubliceerd", Format.long(notice.date))
                    ForEach(distances, id: \.0) { name, text in row("Afstand", "\(text) van \(name)") }
                    if !notice.spatial.isEmpty { row("Locatie", notice.spatial, last: true) }
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if let lat = notice.latitude, let lon = notice.longitude {
                    miniMap(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                }

                if let lookAround {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Straatbeeld")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        LookAroundPreview(initialScene: lookAround)
                            .frame(height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                if !notice.summary.isEmpty || !notice.subject.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Samenvatting")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(notice.summary.isEmpty ? notice.subject : notice.summary)
                            .textSelection(.enabled)
                    }
                }

                Label("Een zienswijze of bezwaar dien je in bij de instantie zelf. Hoe dat gaat, staat in de officiële publicatie.",
                      systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Link(destination: notice.url) {
                    Label("Bekijk officiële publicatie", systemImage: "arrow.up.right.square")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(Theme.accentFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button { showFeedback = true } label: {
                    Label("Klopt er iets niet? Laat het weten", systemImage: "exclamationmark.bubble")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)

                pager
            }
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle(notice.category.label)
        .inlineTitle()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    MarkActions.toggleSaved(notice, in: context)
                    savedTick += 1
                } label: {
                    Image(systemName: index.isSaved(notice) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(index.isSaved(notice) ? "Niet meer bewaren" : "Bewaren")

                if index.isInTrash(notice) {
                    Button { MarkActions.restore(notice, in: context) } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .accessibilityLabel("Zet terug")
                } else {
                    Button {
                        MarkActions.trash(notice, in: context)
                        dismiss()
                    } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Naar prullenbak")
                }

                ShareLink(item: notice.url, subject: Text(notice.title), message: Text(notice.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Delen")
            }
        }
        .sensoryFeedback(.success, trigger: savedTick)
        .sensoryFeedback(.selection, trigger: notice.id)
        .sheet(isPresented: $showFeedback) { FeedbackView(notice: notice) }
        .task(id: notice.id) {
            MarkActions.setRead(notice, in: context)
            lookAround = nil
            if let lat = notice.latitude, let lon = notice.longitude {
                let request = MKLookAroundSceneRequest(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                lookAround = try? await request.scene
            }
        }
    }

    /// Vorige en volgende melding uit de lijst waar je vandaan kwam.
    @ViewBuilder private var pager: some View {
        let n = navigator.neighbours(of: notice)
        if n.previous != nil || n.next != nil {
            HStack(spacing: 12) {
                Button { withAnimation { current = n.previous } } label: {
                    Label("Vorige", systemImage: "chevron.left").frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(n.previous == nil)
                if let pos = navigator.position(of: notice) {
                    Text("\(pos.0) van \(pos.1)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                }
                Button { withAnimation { current = n.next } } label: {
                    Label("Volgende", systemImage: "chevron.right").labelStyle(TrailingIconLabelStyle()).frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(n.next == nil)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }

    private var distances: [(String, String)] {
        places.compactMap { place in
            guard let d = notice.places[place.key], d >= 0 else { return nil }
            return (place.name, Format.distance(d))
        }
    }

    private func row(_ label: String, _ value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            if !last { Divider().padding(.leading, 16) }
        }
    }

    private func miniMap(_ coordinate: CLLocationCoordinate2D) -> some View {
        let place = places.first { notice.places[$0.key] != nil && $0.mode == .radius }
        return Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 700, longitudinalMeters: 700)),
                   interactionModes: [.zoom, .pan]) {
            if let place {
                Annotation(place.name, coordinate: place.coordinate) {
                    Image(systemName: place.symbol)
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Theme.home, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                }
                .annotationTitles(.hidden)
            }
            Annotation(notice.category.label, coordinate: coordinate, anchor: .bottom) {
                CategoryMarker(category: notice.category, selected: true)
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Button {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                item.name = notice.title
                item.openInMaps()
            } label: {
                Text("Open in Kaarten")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }
}

/// Label met het icoon rechts (voor "Volgende").
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.title; configuration.icon }
    }
}
