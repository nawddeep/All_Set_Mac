import AllSetCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TopicChips: View {
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

/// Size and shape for a search.
struct SearchFilters: View {
    let search: PhotoSearch

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
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
        }
        .font(.callout)
    }
}

/// Searches that led somewhere, to run again with one click.
struct RecentSearches: View {
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
struct PhotoThumbnail: View {
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
