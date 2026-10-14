import AllSetCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Library pages work two ways: browsing, where each picture offers to become
/// a widget, and picking, where clicks toggle pictures into `picked`.
struct LibraryContext {
    var picked: Binding<Set<ImageSource>>?
    /// Replaces a tile's usual buttons with one action, e.g. "Set as Wallpaper".
    var action: TileAction?

    struct TileAction {
        let title: String
        let symbol: String
        let run: @MainActor (ImageSource) -> Void
    }

    var isPicking: Bool { picked != nil }

    func isPicked(_ source: ImageSource) -> Bool {
        picked?.wrappedValue.contains(source) ?? false
    }

    func toggle(_ source: ImageSource) {
        guard let picked else { return }
        if picked.wrappedValue.contains(source) {
            picked.wrappedValue.remove(source)
        } else {
            picked.wrappedValue.insert(source)
        }
    }
}

/// A square tile with a hover overlay of actions (browsing) or a checkmark (picking).
private struct LibraryTile<Content: View, Actions: View>: View {
    let source: ImageSource
    let context: LibraryContext
    var caption: String?
    @ViewBuilder var content: (Bool) -> Content
    @ViewBuilder var actions: Actions

    @State private var isHovering = false

    var body: some View {
        let picked = context.isPicked(source)
        // The square decides the size; the picture only fills it. Sized by
        // the picture instead, a tall 9:16 photo spilled into the rows around it.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(minWidth: 0, maxWidth: .infinity)
            .overlay {
                content(isHovering)
                    .scaleEffect(isHovering ? 1.04 : 1)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(picked ? Color.cyan.opacity(0.8) : Color.white.opacity(isHovering ? 0.25 : 0.14), lineWidth: picked ? 1.5 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if context.isPicking {
                    Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                        .padding(8)
                }
            }
            .overlay(alignment: .bottom) {
                if !context.isPicking, isHovering {
                    VStack(spacing: 6) {
                        if let caption {
                            Text(caption)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        actions
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: DS.Radius.card, bottomTrailingRadius: DS.Radius.card))
                    .transition(.opacity)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .onTapGesture { context.toggle(source) }
            .keyboardActivatable(hint: "Picks or unpicks this photo", activate: { context.toggle(source) })
            .onHover { hovering in withMotion(Motion.responsive) { isHovering = hovering } }
    }
}

private struct TileButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(Capsule().fill(Color.white.opacity(0.92)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: Art

struct ArtLibraryPage: View {
    let services: AppServices
    var context = LibraryContext()
    /// Inside another page's scroll (the Wallpaper page's Art source): no
    /// scroll view or page title of its own.
    var embedded = false
    var searchQuery = ""
    var favoriteIDs: Set<String>?

    @State private var palette: ArtPalette?

    var body: some View {
        if embedded {
            content
        } else {
            // Today's piece fills the top of the window, under the navigation.
            BleedScrollPage(showsHero: !context.isPicking) { layout in
                ArtHero(piece: featured, services: services, layout: layout)
            } content: { _ in
                content
            }
        }
    }

    private var pieceCount: Int { ArtStyle.allCases.count * ArtPalette.allCases.count }

    private var content: some View {
        VStack(alignment: .leading, spacing: embedded ? DS.Space.l : DS.Space.section) {
            if embedded {
                SectionHeader(title: "Art", subtitle: "\(pieceCount) generative artworks. Hover to see them move.")
            } else {
                PageHeader(eyebrow: "\(pieceCount) generative artworks", title: "Art",
                           subtitle: "Hover to see them move. Any of them can be a wallpaper, a live scene or a widget background.")
            }
            PaletteFilter(selection: $palette)
            if !searchQuery.isEmpty || favoriteIDs != nil {
                let pieces = ArtPiece.all.filter {
                    (palette == nil || $0.palette == palette) && SearchMatch.containsAll(searchQuery, in: $0.title)
                        && (favoriteIDs == nil || favoriteIDs!.contains(StudioSavedIDs.wallpaperID($0)))
                }
                if pieces.isEmpty {
                    EmptyState(symbol: "magnifyingglass", title: "No wallpapers found", message: "Clear search or turn off Favorites to see the full library.")
                } else {
                    grid(pieces, caption: \.title)
                }
            } else if let palette {
                // One palette: every style in it, side by side.
                grid(ArtStyle.allCases.map { ArtPiece(style: $0, palette: palette) }, caption: \.style.title)
            } else if context.isPicking {
                ForEach(ArtStyle.allCases) { style in
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text(style.title).dsText(.headline)
                        grid(ArtPalette.allCases.map { ArtPiece(style: style, palette: $0) }, caption: \.palette.title)
                    }
                }
            } else {
                // Browsing: a rail per style keeps a long library skimmable.
                ForEach(ArtStyle.allCases) { style in
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        SectionHeader(title: style.title, subtitle: "\(ArtPalette.allCases.count) palettes")
                        MediaRail(items: ArtPalette.allCases.map { ArtPiece(style: style, palette: $0) }, cardWidth: 180) { piece in
                            tile(piece, caption: piece.palette.title)
                        }
                    }
                }
            }
        }
    }

    /// Changes once a day, so the page opens on something new.
    private var featured: ArtPiece {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        let styles = ArtStyle.allCases, palettes = ArtPalette.allCases
        return ArtPiece(style: styles[day % styles.count], palette: palettes[(day / styles.count + day) % palettes.count])
    }

    private func grid(_ pieces: [ArtPiece], caption: KeyPath<ArtPiece, String>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: DS.Space.s)], spacing: DS.Space.s) {
            ForEach(pieces) { piece in
                tile(piece, caption: piece[keyPath: caption])
            }
        }
    }

    private func tile(_ piece: ArtPiece, caption: String) -> some View {
        LibraryTile(source: .art(piece), context: context, caption: caption) { hovering in
            ArtView(piece: piece, animated: hovering)
        } actions: {
            if let action = context.action {
                TileButton(title: action.title, symbol: action.symbol) { action.run(.art(piece)) }
            } else {
                TileButton(title: "Live Scene", symbol: "sparkles") { addScene(piece) }
                TileButton(title: "Wallpaper", symbol: "photo.artframe") {
                    services.pickWallpaper(.art(piece))
                }
            }
        }
    }

    private func addScene(_ piece: ArtPiece) {
        var scene = WidgetInstance(kind: .ambient)
        scene.options.art = piece
        services.addWidget(scene)
    }
}

/// The Art page's lead piece, full width; it moves under the pointer.
private struct ArtHero: View {
    let piece: ArtPiece
    let services: AppServices
    let layout: BleedLayout

    @State private var isHovering = false

    var body: some View {
        HeroSection(eyebrow: "Today\u{2019}s piece", title: piece.style.title,
                    metadata: [piece.palette.title, "Generative", "Moves on hover"], bleed: layout) {
            ArtView(piece: piece, animated: isHovering)
        } actions: {
            Button {
                services.pickWallpaper(.art(piece))
            } label: {
                Label("Set as Wallpaper", systemImage: "photo.artframe")
            }
            .buttonStyle(.pillProminent)
            Button {
                var scene = WidgetInstance(kind: .ambient)
                scene.options.art = piece
                services.addWidget(scene)
            } label: {
                Label("Add Live Scene", systemImage: "sparkles")
            }
            .buttonStyle(.pill)
        }
        .onHover { isHovering = $0 }
    }
}

private struct PaletteFilter: View {
    @Binding var selection: ArtPalette?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.xs) {
                chip(title: "All Palettes", colors: [.white.opacity(0.5), .white.opacity(0.15)], value: nil)
                ForEach(ArtPalette.allCases) { palette in
                    chip(title: palette.title, colors: palette.colors[2...4].map { Color($0) }, value: palette)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, colors: [Color], value: ArtPalette?) -> some View {
        let isSelected = selection == value
        return Button {
            withMotion(Motion.standard) { selection = value }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(.black.opacity(isSelected ? 0.15 : 0)))
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isSelected ? Color.black.opacity(0.88) : DS.Ink.secondary)
            .padding(.leading, DS.Space.xs)
            .padding(.trailing, DS.Space.s)
            .frame(height: 28)
            .background(Capsule().fill(isSelected ? Color.white.opacity(0.92) : DS.Surface.raised))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Online photos

struct WebPhotosPage: View {
    let services: AppServices
    var context = LibraryContext()

    @State private var query = ""
    /// What's shown with nothing typed: a topic, or nil for Unsplash picks.
    @State private var topic: String? = "Landscape"
    @FocusState private var searchFocused: Bool

    private var typed: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        let library = services.images
        let search = services.search
        let showsPicks = typed.isEmpty && topic == nil
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Photos", subtitle: showsPicks
                           ? "Photos by Unsplash photographers. Search, or pick a topic, for more."
                           : "Wallpapers from Wallhaven and free photos from Openverse, searched together. Hover one to see where it's from.")
                SearchBar(text: $query, focused: $searchFocused, isSearching: search.isSearching)
                    .onChange(of: query) { _, text in
                        let trimmed = text.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty {
                            if let topic { search.search(topic, immediately: true) }
                        } else {
                            search.search(trimmed)
                        }
                    }
                    .onSubmit {
                        guard !typed.isEmpty else { return }
                        search.search(typed, immediately: true)
                        search.remember(typed)
                    }

                if typed.isEmpty, !search.recent.isEmpty {
                    RecentSearches(recent: search.recent, clear: { search.clearRecent() }) { query = $0 }
                }

                TopicChips(selection: typed.isEmpty ? topic : nil) { choice in
                    query = ""
                    withMotion(Motion.quick) { topic = choice }
                    if let choice { search.search(choice, immediately: true) }
                }

                if !showsPicks {
                    if let interpretation = search.interpretation {
                        Label(interpretation.hasPrefix("Showing") ? interpretation : "Looking for \(interpretation)",
                              systemImage: interpretation.hasPrefix("Showing") ? "text.badge.checkmark" : "sparkle.magnifyingglass")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                    let art = AestheticSearch.art(matching: typed.isEmpty ? (topic ?? "") : typed, limit: 10)
                    if !art.isEmpty {
                        artMatches(art)
                    }
                    SearchFilters(search: search)
                    photoGrid(search.results) { search.loadMore() }
                    footer(loading: search.isSearching, error: search.errorMessage, hasMore: search.hasMore,
                           empty: search.results.isEmpty && !search.isSearching && search.errorMessage == nil
                               && (typed.count >= 2 || !typed.isEmpty == false),
                           retry: { search.search(typed.isEmpty ? (topic ?? "") : typed, immediately: true) },
                           more: { search.loadMore() })
                    Text("Wallpapers come from the Wallhaven community (safe-for-work only) and belong to their creators: they're for your own desktop. Openverse photos keep their free licenses. Right-click any picture to open its source.")
                        .font(.caption).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    photoGrid(library.webPhotos) { library.loadMoreWebPhotos() }
                    footer(loading: library.isLoadingWebPhotos, error: library.webPhotosError, hasMore: library.hasMoreWebPhotos,
                           empty: false, retry: { library.loadMoreWebPhotos() }, more: { library.loadMoreWebPhotos() })
                    Text("Photos from Unsplash, served by Picsum.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(28)
        }
        .onAppear {
            if let screen = NSScreen.main {
                search.screenPixels = CGSize(width: screen.frame.width * screen.backingScaleFactor,
                                             height: screen.frame.height * screen.backingScaleFactor)
            }
            if !search.query.isEmpty {
                // Come back to what was showing.
                if PhotoSearch.suggestions.contains(search.query) { topic = search.query } else { query = search.query }
            } else if let topic {
                search.search(topic, immediately: true)
            }
            if library.webPhotos.isEmpty { library.loadMoreWebPhotos() }
        }
    }

    /// Built-in art that fits the words: there at once, while photos load.
    private func artMatches(_ pieces: [ArtPiece]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matching art").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pieces) { piece in
                        LibraryTile(source: .art(piece), context: context, caption: piece.title) { hovering in
                            ArtView(piece: piece, animated: hovering)
                        } actions: {
                            if let action = context.action {
                                TileButton(title: action.title, symbol: action.symbol) { action.run(.art(piece)) }
                            } else {
                                TileButton(title: "Live Scene", symbol: "sparkles") {
                                    var scene = WidgetInstance(kind: .ambient)
                                    scene.options.art = piece
                                    services.addWidget(scene)
                                }
                                TileButton(title: "Wallpaper", symbol: "photo.artframe") {
                                    services.pickWallpaper(.art(piece))
                                }
                            }
                        }
                        .frame(width: 150)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func photoGrid(_ photos: [WebPhoto], loadMore: @escaping () -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(photos) { photo in
                LibraryTile(source: .web(photo), context: context, caption: photo.credit) { _ in
                    PhotoThumbnail(photo: photo)
                } actions: {
                    if let action = context.action {
                        TileButton(title: action.title, symbol: action.symbol) { action.run(.web(photo)) }
                    } else {
                        TileButton(title: "Photo Widget", symbol: "plus") {
                            services.search.remember()
                            var widget = WidgetInstance(kind: .photo)
                            widget.options.images = [.web(photo)]
                            services.addWidget(widget)
                        }
                        TileButton(title: "Wallpaper", symbol: "photo.artframe") {
                            services.search.remember()
                            services.pickWallpaper(.photo(.web(photo)))
                        }
                    }
                }
                .contextMenu {
                    if let page = photo.pageURL {
                        Button("Open Source Page") { NSWorkspace.shared.open(page) }
                    }
                    if let full = photo.imageURLString.flatMap(URL.init(string:)) {
                        Button("Open Full Size") { NSWorkspace.shared.open(full) }
                    }
                }
                // Fetch the next page before the end is reached.
                .onAppear { if photos.suffix(8).contains(where: { $0.id == photo.id }) { loadMore() } }
            }
        }
    }

    @ViewBuilder
    private func footer(loading: Bool, error: String?, hasMore: Bool, empty: Bool,
                        retry: @escaping () -> Void, more: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            if loading {
                ProgressView()
            } else if let error {
                VStack(spacing: 8) {
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Try Again", action: retry)
                }
            } else if empty {
                ContentUnavailableView.search(text: query)
            } else if hasMore {
                Button("Load More", action: more)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

/// A search field with a magnifying glass, a spinner while searching, and a
/// clear button.
private struct SearchBar: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let isSearching: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search wallpapers: Marvel, anime, Lamborghini, rain…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused(focused)
            if isSearching {
                ProgressView().controlSize(.small)
            }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.primary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(focused.wrappedValue ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 2))
    }
}

private struct TopicChips: View {
    let selection: String?
    let onPick: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Unsplash picks", value: nil, selected: selection == nil)
                ForEach(PhotoSearch.suggestions, id: \.self) { topic in
                    chip(topic, value: topic, selected: selection == topic)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ title: String, value: String?, selected: Bool) -> some View {
        Button {
            onPick(value)
        } label: {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(selected ? Color.white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Color.accentColor : Color.primary.opacity(0.07)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Order, size, shape and color for a search. Sorting and colors come from
/// Wallhaven, so choosing one searches Wallhaven alone.
private struct SearchFilters: View {
    let search: PhotoSearch

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Picker("Sort", selection: Binding(get: { search.sort }, set: { search.sort = $0 })) {
                    ForEach(Wallhaven.Sort.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 180)
                Picker("Size", selection: Binding(get: { search.minimumSize }, set: { search.minimumSize = $0 })) {
                    ForEach(PhotoSearch.MinimumSize.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 220)
                Picker("Shape", selection: Binding(get: { search.orientation }, set: { search.orientation = $0 })) {
                    ForEach(PhotoSearch.Orientation.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)
                Spacer(minLength: 0)
            }
            .controlSize(.small)
            HStack(spacing: 6) {
                Text("Color").font(.callout).foregroundStyle(.secondary)
                swatch(nil)
                ForEach(Wallhaven.colors, id: \.self) { swatch($0) }
            }
        }
        .font(.callout)
    }

    private func swatch(_ hex: String?) -> some View {
        let selected = search.color == hex
        return Button {
            withMotion(Motion.quick) { search.color = selected ? nil : hex }
        } label: {
            Circle()
                .fill(hex.map { Color(hex: Int($0, radix: 16) ?? 0) } ?? Color.clear)
                .overlay {
                    if hex == nil {
                        Image(systemName: "circle.slash").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
                .frame(width: 18, height: 18)
                .padding(2)
                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: selected ? 2 : 0))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .help(hex == nil ? "Any color" : "Mostly #\(hex!)")
    }
}

/// Searches that led somewhere, to run again with one click.
private struct RecentSearches: View {
    let recent: [String]
    let clear: () -> Void
    let pick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                ForEach(recent, id: \.self) { text in
                    Button { pick(text) } label: {
                        Text(text)
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().strokeBorder(Color.primary.opacity(0.18)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
                Button("Clear", action: clear)
                    .buttonStyle(.link)
                    .font(.callout)
            }
            .padding(.vertical, 2)
        }
    }
}

/// A photo's thumbnail: the site's own small copy, then Openverse's, then the
/// full photo, fading in once it arrives.
private struct PhotoThumbnail: View {
    let photo: WebPhoto

    @State private var attempt = 0

    private var urls: [URL] {
        var urls = [photo.thumbnailURL(side: 320)]
        if let fallback = photo.fallbackThumbnailURL, !urls.contains(fallback) { urls.append(fallback) }
        if !urls.contains(photo.displayURL) { urls.append(photo.displayURL) }
        return urls
    }

    var body: some View {
        let urls = urls
        AsyncImage(url: urls[min(attempt, urls.count - 1)], transaction: Transaction(animation: .easeOut(duration: 0.35))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            case .failure:
                Rectangle().fill(.quaternary)
                    .task { if attempt < urls.count - 1 { attempt += 1 } }
            default:
                Rectangle().fill(.quaternary)
                    .overlay { ProgressView().controlSize(.small).opacity(0.5) }
            }
        }
        .id(attempt)
    }
}

// MARK: Your photos

struct MyPhotosPage: View {
    let services: AppServices
    var context = LibraryContext()

    @State private var slideshow = Set<ImageSource>()
    @State private var isDropTarget = false

    var body: some View {
        let library = services.images
        // Browsing picks for a new slideshow; picking for a widget uses the caller's set.
        let pageContext = context.isPicking || context.action != nil ? context : LibraryContext(picked: $slideshow)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    PageHeader(title: "My Photos", subtitle: "Import pictures or whole folders, or drop them here. Select several to make a slideshow.")
                    Spacer()
                    Button {
                        importWithPanel()
                    } label: {
                        Label("Import…", systemImage: "square.and.arrow.down")
                    }
                    .controlSize(.large)
                }

                if let progress = library.importProgress {
                    HStack(spacing: 10) {
                        ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                        Text("Importing \(progress.done) of \(progress.total)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button("Stop") { library.cancelImports() }
                    }
                }

                if library.userImages.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Drop photos or folders here").font(.headline)
                        Text("They're copied into All Set, so moving the originals won't break your widgets.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .background(RoundedRectangle(cornerRadius: 16).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .foregroundStyle(.quaternary))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(library.userImages, id: \.self) { name in
                            LibraryTile(source: .file(name), context: pageContext) { _ in
                                FileThumbnail(url: library.userImageURL(name), images: library, maxPixels: 400)
                            } actions: {
                                if let action = context.action {
                                    TileButton(title: action.title, symbol: action.symbol) { action.run(.file(name)) }
                                }
                            }
                            .contextMenu {
                                Button("Set as Wallpaper") { services.pickWallpaper(.photo(.file(name))) }
                                Button("New Photo Widget") {
                                    var widget = WidgetInstance(kind: .photo)
                                    widget.options.images = [.file(name)]
                                    services.addWidget(widget)
                                }
                                Button("Delete", role: .destructive) { library.deleteUserImage(name) }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor, lineWidth: 3).padding(8)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            // Imported in the background; progress shows above.
            Task { await library.importImages(from: urls) }
            return !urls.isEmpty
        } isTargeted: { isDropTarget = $0 }
        .safeAreaInset(edge: .bottom) {
            if !context.isPicking, context.action == nil, !slideshow.isEmpty {
                HStack {
                    Text("\(slideshow.count) selected")
                    Spacer()
                    Button("Clear") { slideshow.removeAll() }
                    Button {
                        var widget = WidgetInstance(kind: .photo, size: .medium)
                        widget.options.images = library.userImages.map { ImageSource.file($0) }.filter(slideshow.contains)
                        widget.options.slideshowInterval = slideshow.count > 1 ? 600 : 0
                        services.addWidget(widget)
                        slideshow.removeAll()
                    } label: {
                        Label(slideshow.count > 1 ? "New Slideshow Widget" : "New Photo Widget", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(14)
                .background(.bar)
            }
        }
    }

    private func importWithPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.image, .folder]
        panel.prompt = "Import"
        if panel.runModal() == .OK {
            let urls = panel.urls
            Task { await services.images.importImages(from: urls) }
        }
    }
}

/// A sheet for choosing pictures for a photo widget from any library.
struct LibraryPicker: View {
    let services: AppServices
    let onDone: ([ImageSource]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var picked = Set<ImageSource>()

    var body: some View {
        let context = LibraryContext(picked: $picked)
        VStack(spacing: 0) {
            Picker("Library", selection: $tab) {
                Text("Art").tag(0)
                Text("Photos").tag(1)
                Text("My Photos").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Group {
                switch tab {
                case 0: ArtLibraryPage(services: services, context: context)
                case 1: WebPhotosPage(services: services, context: context)
                default: MyPhotosPage(services: services, context: context)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text(picked.isEmpty ? "Click pictures to choose them" : "\(picked.count) chosen")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add \(picked.count)") {
                    onDone(Array(picked))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(picked.isEmpty)
            }
            .padding(14)
            .background(.bar)
        }
        .frame(width: 860, height: 640)
    }
}
