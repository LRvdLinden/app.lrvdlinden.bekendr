import SwiftUI
import MapKit

/// Meldingen op de kaart: ronde punten in de categoriekleur, de straal of het gebied van elke locatie,
/// en onderaan een kaart met de gekozen melding.
struct NoticeMapView: View {
    let notices: [Notice]
    let places: [Place]
    let marks: MarkIndex
    let placeNames: [String: String]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedID: String?

    private var located: [Notice] { notices.filter(\.hasCoordinate) }
    private var selected: Notice? { located.first { $0.id == selectedID } }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position, selection: $selectedID) {
                ForEach(places) { place in
                    if place.mode == .radius {
                        MapCircle(center: place.coordinate, radius: place.radius)
                            .foregroundStyle(Theme.accentFill.opacity(0.08))
                            .stroke(Theme.accentFill.opacity(0.55), lineWidth: 2)
                    }
                    Annotation(place.name, coordinate: place.coordinate, anchor: .center) {
                        Image(systemName: place.symbol)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.home, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(located) { notice in
                    Annotation(notice.category.label,
                               coordinate: CLLocationCoordinate2D(latitude: notice.latitude!, longitude: notice.longitude!),
                               anchor: .bottom) {
                        CategoryMarker(category: notice.category, selected: notice.id == selectedID)
                            .opacity(marks.isUnread(notice) || notice.id == selectedID ? 1 : 0.8)
                    }
                    .annotationTitles(.hidden)
                    .tag(notice.id)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            VStack(spacing: 10) {
                if located.count < notices.count {
                    Text("\(notices.count - located.count) meldingen zonder punt op de kaart staan in de lijst.")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
                if let notice = selected {
                    NavigationLink(value: notice) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: notice.category.symbol)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(notice.category.color)
                                .frame(width: 42, height: 42)
                                .background(notice.category.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(notice.category.label) · \(Format.day(notice.date))")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(notice.category.textColor)
                                Text(notice.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                if let distance = closest(notice) {
                                    Text(distance).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(12)
            .frame(maxWidth: 560)
        }
        .animation(.easeOut(duration: 0.2), value: selectedID)
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    private func closest(_ notice: Notice) -> String? {
        guard let best = notice.places.filter({ $0.value >= 0 }).min(by: { $0.value < $1.value }),
              let name = placeNames[best.key] else { return nil }
        return "\(Format.distance(best.value)) van \(name)"
    }
}
