import AllSetCore
import AppKit
import SwiftUI

struct GalleryPage: View {
    let category: WidgetCategory?
    let services: AppServices
    @State private var filter = StudioWidgetFilter.all
    @State private var query = ""
    @State private var selected = "digitalClock"
    @State private var size = WidgetSize.medium
    @State private var material = WidgetMaterial.dark
    @State private var added = false
    @State private var direction = 1
    @State private var swipe: CGFloat = 0
    @State private var favoritesOnly = false
    @State private var customizing = false
    @State private var use24Hour = false
    @State private var background = StudioScenery.wallpaper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("studio.widgetFavorites") private var favorites = ""
    init(category: WidgetCategory?, services: AppServices) {
        self.category = category; self.services = services
        _filter = State(initialValue: category == nil ? services.ui.studioWidgetFilter : .all)
        let selected = services.ui.studioWidgetSelection
        _selected = State(initialValue: selected)
        _size = State(initialValue: WidgetCatalog.entry(selected)?.defaultSize ?? .medium)
    }
    private let recommendations = ["weather", "calendar", "systemMonitor", "focusTimer", "music"]
    private let spotlightIDs = ["digitalClock", "analogClock", "weather", "calendar", "systemMonitor", "focusTimer", "music"]
    private var entry: CatalogEntry { WidgetCatalog.entry(selected) ?? WidgetCatalog.entries[0] }
    private var availableSizes: [WidgetSize] { selected == "digitalClock" ? WidgetSize.allCases : entry.sizes }
    private var sample: WidgetInstance { make(entry, size: size) }
    private var showsStage: Bool { query.isEmpty && filter == .all && !favoritesOnly && category == nil && !services.ui.galleryFromThemes }
    private var scrollStart: String { showsStage ? "studio.hero" : "studio.catalog.top" }
    private var styles: [(String, WidgetMaterial)] { [("Dark", .dark), ("Photo", .photo), ("Solid", .paper), ("Outline", .outline), ("Mesh", .mesh)] }
    private func make(_ entry: CatalogEntry, size: WidgetSize? = nil) -> WidgetInstance {
        guard recommendations.contains(entry.id) || entry.id == "digitalClock" || entry.id == "analogClock" else { return entry.make(size: size ?? entry.defaultSize) }
        var instance = entry.make(size: size ?? (CinematicWidgetFace.supports(entry.kind) ? .medium : entry.defaultSize))
        instance.options.designTheme = nil
        instance.options.cinematicStyle = recommendations.contains(entry.id) || entry.id == "analogClock"
        if entry.kind == .focus {
            instance.options.focusMinutes = 25
        }
        instance.material = material
        instance.options.appearance = .dark
        instance.options.ink = WidgetColor(hex: 0xFFFFFF)
        instance.options.background = .bundled(entry.kind == .focus && background == StudioScenery.wallpaper ? StudioScenery.widgets : background)
        instance.options.art = ArtPiece(style: .aurora, palette: .midnight)
        // Previews show the month without reading the calendar; `installable` turns
        // events back on for a calendar that goes on the desktop.
        if entry.kind == .calendar { instance.options.showEvents = false }
        if entry.id == "digitalClock" {
            instance.options.cinematicClock = true
            instance.options.use24Hour = use24Hour
            if instance.size == .medium { instance.stretch = 0.85 }
        }
        if entry.kind == .weather {
            instance.material = material == .frosted ? .tinted : material
            // A city already on the desktop, else one guessed from this Mac's time zone:
            // never a fixed city the person didn't choose.
            instance.options.location = services.widgets.widgets.lazy.compactMap(\.options.location).first ?? TimeZonePlace.guess()
        }
        return instance
    }
    var body: some View {
        GeometryReader { g in
            let layout = StudioLayout(width: g.size.width, height: g.size.height + 102)
            VStack(spacing: DS.Space.xs) {
                toolbar(width: g.size.width).padding(.horizontal, DS.Space.pageMargin(for: g.size.width))
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            if showsStage {
                                stage(layout).id("studio.hero")
                                controls.padding(.bottom, 16)
                                library(layout, entries: recommendations.compactMap(WidgetCatalog.entry), title: "Explore widgets", subtitle: "Small tools. A better desktop.") {
                                    withMotion(Motion.gentle) { proxy.scrollTo("studio.catalog.top", anchor: .top) }
                                }
                            }
                            CinematicCatalog(services: services, width: layout.width - 2 * DS.Space.pageMargin(for: layout.width),
                                             filter: filter, category: category, query: query,
                                             themesOnly: services.ui.galleryFromThemes,
                                             favoriteIDs: favoritesOnly ? StudioSavedIDs.decode(favorites) : nil)
                                .padding(.horizontal, DS.Space.pageMargin(for: layout.width)).padding(.top, DS.Space.l).padding(.bottom, DS.Space.xxl)
                        }.background(LibraryScrollActivity())
                    }.id("\(filter.id)|\(query)|\(category?.id ?? "all")|\(services.ui.galleryFromThemes)|\(favoritesOnly)")
                    .accessibilityIdentifier("studio.widgets.scroll")
                    .onChange(of: filter) { _, _ in proxy.scrollTo(scrollStart, anchor: .top) }
                    .onChange(of: query) { _, _ in proxy.scrollTo(scrollStart, anchor: .top) }
                    .onChange(of: services.ui.galleryFromThemes) { _, _ in proxy.scrollTo(scrollStart, anchor: .top) }
                    .onChange(of: favoritesOnly) { _, _ in proxy.scrollTo(scrollStart, anchor: .top) }
                }
            }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $customizing) { customization }
        .onAppear {
            if let location = make(WidgetCatalog.entry("weather")!).options.location {
                services.weather.refreshIfNeeded(location, maxAge: WeatherService.refreshInterval)
            }
        }
    }

    private func toolbar(width: CGFloat) -> some View {
        StudioFilterSurface {
            HStack(spacing: DS.Space.s) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(StudioWidgetFilter.allCases) { option in
                            CinemaChip(title: option.rawValue, selected: filter == option, whiteSelection: true) {
                                withMotion(Motion.standard) {
                                    filter = option; services.ui.studioWidgetFilter = option
                                    services.ui.galleryFromThemes = false; favoritesOnly = false
                                    if category != nil { services.ui.page = .gallery(nil) }
                                }
                            }
                        }
                    }
                }
                Rectangle().fill(DS.Surface.hairline).frame(width: 1, height: 18)
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search widgets…", text: $query).textFieldStyle(.plain).accessibilityLabel("Search widgets")
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(width: 24, height: 24).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Clear widget search")
                    }
                }.font(.system(size: 12)).foregroundStyle(DS.Ink.secondary)
                    .frame(width: width < 1064 ? 164 : 190, height: 32)
                Menu {
                    Button("All catalog widgets") { services.ui.galleryFromThemes = false; filter = .all; services.ui.studioWidgetFilter = .all; services.ui.page = .gallery(nil) }
                    Toggle("Favorite widgets", isOn: $favoritesOnly)
                    Button("From Themes") { withMotion(Motion.standard) { services.ui.galleryFromThemes = true; services.ui.page = .gallery(nil) } }
                    ForEach(WidgetCategory.allCases) { option in Button(option.title) { services.ui.page = .gallery(option) } }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel("All widget categories")
            }
        }
    }

    private func stage(_ layout: StudioLayout) -> some View {
        let fit = previewFit(CGSize(width: layout.spotlightWidth, height: layout.spotlightHeight))
        return HStack(spacing: 0) {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(FloatingButtonStyle(diameter: 28)).accessibilityLabel("Previous widget")
            Spacer(minLength: 10)
            neighbour(-1, layout: layout)
            Spacer(minLength: 24)
            ZStack {
                CinemaWidgetPreview(instance: sample, services: services, fit: fit, live: true)
                    .id(selected)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .offset(x: CGFloat(direction) * 160).combined(with: .opacity).combined(with: .scale(scale: 0.93)), removal: .offset(x: CGFloat(-direction) * 160).combined(with: .opacity)))
            }
                .offset(x: reduceMotion ? 0 : max(-80, min(80, swipe * 0.4)))
                .frame(width: fit.width, height: fit.height)
                .accessibilityElement(children: .contain).accessibilityIdentifier("studio.spotlight")
                .background(CardHalo(spread: .shadow).foregroundStyle(.black).opacity(0.35))
                .overlay(alignment: .bottom) {
                    EllipticalGradient(colors: [.cyan.opacity(0.14), .clear], center: .center,
                                       startRadiusFraction: 0, endRadiusFraction: 0.5)
                        .frame(width: fit.width * 1.4, height: 48).offset(y: 32)
                        .allowsHitTesting(false)
                }
                .motion(reduceMotion ? nil : Motion.responsive, value: fit)
                .motion(Motion.standard, value: material)
            Spacer(minLength: 24)
            neighbour(1, layout: layout)
            Spacer(minLength: 10)
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(FloatingButtonStyle(diameter: 28)).accessibilityLabel("Next widget")
        }.padding(.horizontal, DS.Space.pageMargin(for: layout.width)).frame(height: layout.stageHeight)
        .overlay(CarouselScrollCatcher { input in
            switch input {
            case .moved(let dx): swipe += dx
            case .released(let velocity):
                let travel = swipe + velocity * 10
                if abs(travel) > 45 { move(travel > 0 ? -1 : 1) }
                withMotion(Motion.responsive) { swipe = 0 }
            case .stepped(let step): move(step)
            }
        })
        .simultaneousGesture(DragGesture(minimumDistance: 12).onEnded { value in
            if abs(value.translation.width) > abs(value.translation.height), abs(value.translation.width) > 45 { move(value.translation.width < 0 ? 1 : -1) }
        })
    }
    private func previewFit(_ bounds: CGSize) -> CGSize {
        StudioLayout.fitting(sample.footprint, in: bounds)
    }
    private func neighbour(_ step: Int, layout: StudioLayout) -> some View {
        let index = spotlightIDs.firstIndex(of: selected) ?? 0
        let neighbor = WidgetCatalog.entry(spotlightIDs[StudioLayout.wrapped(index + step, count: spotlightIDs.count)!])!
        let width = layout.sideWidth
        return Button { direction = step; select(neighbor.id) } label: {
            CinemaWidgetPreview(instance: make(neighbor), services: services,
                                fit: CGSize(width: width - 16, height: width * 0.72 - 16))
                .frame(width: width, height: width * 0.72)
                .background(DS.Surface.canvasLift, in: RoundedRectangle(cornerRadius: DS.Radius.panel))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.panel).strokeBorder(DS.Surface.hairline))
        }.buttonStyle(.plain).accessibilityLabel("Show \(neighbor.title)")
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(step) * -9), axis: (x: 0, y: 1, z: 0), perspective: 0.2)
            .opacity(0.78)
    }
    private var controls: some View {
        VStack(spacing: DS.Space.xs) {
            HStack(spacing: 0) {
                ForEach(spotlightIDs, id: \.self) { id in
                    Button { select(id) } label: {
                        Circle().fill(id == selected ? Color.white : Color.white.opacity(0.25))
                            .frame(width: 5, height: 5)
                            .frame(width: 17, height: 24).contentShape(Rectangle())
                    }
                        .buttonStyle(.plain).accessibilityLabel("Show \(WidgetCatalog.entry(id)?.title ?? id)")
                        .accessibilityAddTraits(id == selected ? .isSelected : [])
                }
            }
            sizeControl
            VStack(spacing: 3) {
                Text(entry.title).font(.system(size: 26, weight: .bold)).tracking(-0.5)
                Text(selected == "digitalClock" ? "Time, date and a quieter desktop." : entry.summary).dsText(.meta)
            }
            styleControl
            HStack(spacing: 12) {
                Button { add(sample) } label: { Label(added ? "Added" : "Add to Desktop", systemImage: added ? "checkmark" : "plus").font(.system(size: 13, weight: .semibold)).frame(minWidth: 152) }.buttonStyle(.pillProminent)
                Button { toggleFavorite(selected) } label: { Image(systemName: isFavorite(selected) ? "heart.fill" : "heart") }
                    .buttonStyle(FloatingButtonStyle(diameter: 32)).accessibilityLabel("Favorite \(entry.title)").accessibilityValue(isFavorite(selected) ? "Saved" : "Not saved")
                Button("Customize") { customizing = true }.buttonStyle(.pill)
            }.padding(.top, 6)
        }
    }
    private var sizeControl: some View {
        StudioSegmentedControl(values: availableSizes, selection: $size, title: { $0.shortTitle },
                               horizontalPadding: 23.25, label: "Widget size")
    }
    private var styleControl: some View {
        StudioSegmentedControl(values: styles.map(\.1), selection: $material,
                               title: { value in styles.first { $0.1 == value }!.0 },
                               horizontalPadding: 26, label: "Widget style")
    }
    private func library(_ layout: StudioLayout, entries: [CatalogEntry], title: String, subtitle: String, seeAll: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "square.stack.3d.up").font(.system(size: 17, weight: .semibold))
                    .frame(width: 30, height: 30).background(DS.Surface.raised, in: RoundedRectangle(cornerRadius: DS.Radius.control))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).dsText(.section)
                    Text(subtitle).dsText(.meta)
                }
                Spacer()
                Button("See all", action: seeAll).buttonStyle(.pill).controlSize(.small)
            }
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(Array(stride(from: 0, to: entries.count, by: layout.columns)), id: \.self) { start in
                    HStack(alignment: .top, spacing: DS.Space.s) {
                        ForEach(Array(entries[start..<min(start + layout.columns, entries.count)])) { entry in tile(entry, layout: layout) }
                    }.frame(height: layout.tileHeight + 44, alignment: .top)
                }
            }
        }
        .padding(.horizontal, DS.Space.pageMargin(for: layout.width)).padding(.top, DS.Space.l).padding(.bottom, DS.Space.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func tile(_ entry: CatalogEntry, layout: StudioLayout) -> some View {
        let tileWidth = (layout.width - 2 * DS.Space.pageMargin(for: layout.width) - CGFloat(layout.columns - 1) * DS.Space.s) / CGFloat(layout.columns)
        return VStack(alignment: .leading, spacing: 7) {
            Button { select(entry.id) } label: {
                CinemaWidgetPreview(instance: make(entry), services: services, fit: CGSize(width: tileWidth - 12, height: layout.tileHeight - 12))
                    .frame(width: tileWidth, height: layout.tileHeight)
                    .background(DS.Surface.canvasLift, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).strokeBorder(DS.Surface.hairline))
            }.buttonStyle(.plain).accessibilityLabel("Preview \(entry.title)")
                .overlay(alignment: .topTrailing) {
                    Button { toggleFavorite(entry.id) } label: { Image(systemName: isFavorite(entry.id) ? "heart.fill" : "heart").font(.system(size: 15)) }
                        .buttonStyle(FloatingButtonStyle(diameter: 26)).padding(DS.Space.xs).accessibilityLabel("Favorite \(entry.title)").accessibilityValue(isFavorite(entry.id) ? "Saved" : "Not saved")
                }
                .onDrag { let widget = installable(make(entry)); services.ui.widgetDrop = widget; return NSItemProvider(object: entry.title as NSString) }
            HStack {
                Text(entry.id == "music" ? "Music Player" : entry.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                Spacer(minLength: 2)
                Button { add(make(entry)) } label: { Image(systemName: "plus") }
                    .buttonStyle(FloatingButtonStyle(diameter: 28)).accessibilityLabel("Add \(entry.title) to Desktop")
            }
        }.frame(width: tileWidth).accessibilityElement(children: .contain).accessibilityIdentifier("studio.tile.\(entry.id)")
    }
    private var customization: some View {
        VStack(spacing: 16) {
            HStack { Text("Customize \(entry.title)").font(.title2); Spacer(); Button("Done") { customizing = false } }
            CinemaWidgetPreview(instance: sample, services: services, fit: previewFit(CGSize(width: 480, height: 210))).frame(height: 210)
            sizeControl
            styleControl
            HStack(spacing: 12) {
                ForEach([StudioScenery.wallpaper, StudioScenery.aurora, StudioScenery.coast], id: \.self) { name in
                    Button { background = name } label: { CinemaImage(name: name).frame(width: 142, height: 82).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(background == name ? 1 : 0.1))) }.buttonStyle(.plain).accessibilityLabel("Background \(name)")
                }
            }
            if entry.kind == .clock { Toggle("24-hour clock", isOn: $use24Hour).frame(width: 220) }
            Button { add(sample); customizing = false } label: { Label("Add to Desktop", systemImage: "plus") }.buttonStyle(.pillProminent)
        }.padding(28).frame(width: 680).background(DS.Surface.canvasLift).preferredColorScheme(.dark)
    }
    private func select(_ id: String) {
        guard selected != id else { return }
        withMotion(Motion.responsive) {
            selected = id; services.ui.studioWidgetSelection = id; size = WidgetCatalog.entry(id)?.defaultSize ?? .medium
            if id == "digitalClock" { size = .medium }
        }
    }
    private func move(_ step: Int) {
        direction = step < 0 ? -1 : 1
        let index = spotlightIDs.firstIndex(of: selected) ?? 0
        if let next = StudioLayout.wrapped(index + step, count: spotlightIDs.count) { select(spotlightIDs[next]) }
    }
    /// What goes on the desktop, as opposed to a preview: a calendar shows the
    /// person's events (macOS asks for access the first time).
    private func installable(_ instance: WidgetInstance) -> WidgetInstance {
        var instance = instance
        if instance.kind == .calendar { instance.options.showEvents = true }
        return instance
    }

    private func add(_ preview: WidgetInstance) {
        let instance = installable(preview)
        services.addWidget(instance); added = true
        let message = switch instance.kind {
        case .weather: "Weather for \(instance.options.location?.name ?? "your area") added: change the city in Edit Widget"
        case .calendar: "Calendar added: it shows your events once Calendar access is allowed"
        default: "\(instance.kind.title) added to desktop"
        }
        services.ui.toast = Toast(message: message, symbol: "plus")
        Task { try? await Task.sleep(for: .seconds(2)); added = false }
    }
    private func isFavorite(_ id: String) -> Bool { StudioSavedIDs.decode(favorites).contains(id) }
    private func toggleFavorite(_ id: String) {
        var values = StudioSavedIDs.decode(favorites)
        if !values.insert(id).inserted { values.remove(id) }
        favorites = StudioSavedIDs.encode(values)
    }
}
