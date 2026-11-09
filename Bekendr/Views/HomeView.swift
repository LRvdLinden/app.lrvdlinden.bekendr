import SwiftUI
import SwiftData

/// "Jouw buurt": per locatie wat er nieuw is, met tegels per categorie.
struct HomeView: View {
    @Environment(NoticeStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Query(sort: \Place.sortOrder) private var places: [Place]
    @Query private var marks: [NoticeMark]
    @State private var selectedKey: String?
    @State private var editing: Place?
    @State private var adding = false
    @State private var weather = WeatherStore.shared

    private var selected: Place? {
        places.first { $0.key == selectedKey } ?? places.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    placeChips
                    if let place = selected {
                        summary(for: place)
                        today(for: place)
                        categories(for: place)
                        if let error = store.lastError {
                            Label(error, systemImage: "wifi.exclamationmark")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ContentUnavailableView {
                            Label("Nog geen locaties", systemImage: "mappin.slash")
                        } description: {
                            Text("Voeg een adres of wijk toe om bekendmakingen in de buurt te zien.")
                        } actions: {
                            Button("Locatie toevoegen") { adding = true }.buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Jouw buurt")
            .largeTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if store.isLoading { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .accessibilityLabel("Nu controleren")
                    .disabled(store.isLoading)
                }
            }
            .refreshable { await refresh() }
            .navigationDestination(for: Notice.self) { NoticeDetailView(notice: $0) }
            .navigationDestination(for: NoticeFilter.self) { NoticeListScreen(filter: $0) }
            .sheet(item: $editing) { place in
                NavigationStack { PlaceEditorView(place: place) }
            }
            .sheet(isPresented: $adding) {
                NavigationStack { PlaceEditorView(place: nil) }
            }
        }
    }

    private func refresh() async {
        let infos = places.map(PlaceInfo.init)
        await store.refresh(places: infos, notify: false)
        WidgetSync.update(places: infos)
    }

    // MARK: Onderdelen

    private var placeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(places) { place in
                    let isOn = place.key == selected?.key
                    Button {
                        selectedKey = place.key
                    } label: {
                        Label(place.name, systemImage: place.symbol)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).frame(height: 36)
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .background(isOn ? Theme.home : Theme.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(isOn ? .clear : Theme.line))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Bewerken", systemImage: "pencil") { editing = place }
                    }
                }
                Button { adding = true } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(Theme.muted, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .accessibilityLabel("Locatie toevoegen")
            }
            .padding(.vertical, 2)
        }
    }

    private func visible(for place: Place) -> [Notice] {
        let index = MarkIndex(marks)
        return store.notices(for: place.key).filter { !index.isTrashed($0) }
    }

    private func summary(for place: Place) -> some View {
        let list = visible(for: place)
        let index = MarkIndex(marks)
        let newCount = list.filter(index.isUnread).count
        let today = list.filter { Calendar.current.isDateInToday($0.date) }.count
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let week = list.filter { $0.date >= weekAgo }.count
        return NavigationLink(value: NoticeFilter(placeKey: place.key, category: nil, scope: newCount > 0 ? .unread : .all)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(newCount == 1 ? "1 nieuwe" : "\(newCount) nieuwe")
                            .font(.title.weight(.heavy))
                        Text(place.mode == .route ? "binnen \(Format.distance(place.radius)) van de route \(place.shortAddress)"
                             : place.mode == .radius ? "binnen \(Format.distance(place.radius)) van \(place.shortAddress)"
                                                   : "in \(place.shortAddress)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    Text("Bekijk")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 12).frame(height: 32)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                HStack(spacing: 20) {
                    Text("**\(today)** vandaag")
                    Text("**\(week)** afgelopen 7 dagen")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Vandaag: het weer en wat er vandaag is bekendgemaakt bij deze locatie.
    private func today(for place: Place) -> some View {
        let index = MarkIndex(marks)
        let list = visible(for: place).filter { Calendar.current.isDateInToday($0.date) }
        let names = Dictionary(places.map { ($0.key, $0.name) }, uniquingKeysWith: { a, _ in a })
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Vandaag").font(.title3.weight(.heavy))
                Text(Format.today()).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if let w = weather.weather(for: place.key) {
                    Label {
                        Text("\(w.temperatureText) · \(w.description)")
                    } icon: {
                        Image(systemName: w.symbol).symbolRenderingMode(.multicolor)
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel("Weer bij \(place.name): \(w.temperatureText), \(w.description)")
                }
            }
            VStack(spacing: 0) {
                if list.isEmpty {
                    Label("Vandaag nog niets bekendgemaakt bij \(place.name).", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(list.prefix(4)) { notice in
                        NavigationLink(value: notice) {
                            NoticeRow(notice: notice, unread: index.isUnread(notice), placeNames: names)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if notice.id != list.prefix(4).last?.id { Divider().padding(.leading, 35) }
                    }
                    if list.count > 4 {
                        Divider()
                        NavigationLink(value: NoticeFilter(placeKey: place.key, category: nil, scope: .all)) {
                            Text("Bekijk alle \(list.count) van vandaag")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if weather.weather(for: place.key) != nil {
                Text("Weer: Open-Meteo").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .onAppear { NoticeNavigator.shared.sequence = list }
        .task(id: place.key) {
            await weather.load(key: place.key, latitude: place.latitude, longitude: place.longitude)
        }
    }

    private func categories(for place: Place) -> some View {
        let list = visible(for: place)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Categorieën").font(.title3.weight(.heavy))
                Spacer()
                Button("Beheren") { editing = place }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(NoticeCategory.allCases.filter { place.categories.contains($0) }) { category in
                    let count = list.filter { $0.category == category }.count
                    NavigationLink(value: NoticeFilter(placeKey: place.key, category: category, scope: .all)) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: category.symbol)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(category.color)
                                    .frame(width: 38, height: 38)
                                    .background(category.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Spacer()
                                Text("\(count)").font(.title2.weight(.heavy))
                            }
                            Text(category.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(category.name): \(count)")
                }
            }
        }
    }
}
