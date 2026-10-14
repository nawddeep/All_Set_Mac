import AllSetCore
import AppKit
import AVFoundation
import SwiftUI

/// The current wallpaper and the person's video library, in one scroll.
struct ClassicWallpaperPage: View {
    let services: AppServices
    /// The library's detail sheet overlays the whole page, so it lives here.
    @State private var detailVideo: LibraryVideo?
    /// Shows only wallpapers downloaded to this Mac. A view filter only: it
    /// never changes what Delete does.
    @State private var ownedOnly = false
    @State private var isDropTarget = false
    var body: some View {
        ZStack(alignment: .top) {
            pageContent
            // Only the shared navigation floats over the wallpaper now.
            LinearGradient(stops: [.init(color: .black.opacity(0.65), location: 0),
                                   .init(color: .black.opacity(0.44), location: 0.62),
                                   .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 182).allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    @ViewBuilder private var pageContent: some View {
        let store = services.wallpaper
        ZStack(alignment: .bottom) {
            // What's on the desktop fills the top of the window, under the
            // navigation; the sources climb onto its faded bottom.
            BleedScrollPage { layout in
                let heroLayout = BleedLayout(topInset: 102, visibleHeight: max(440, layout.height) - 102,
                                             margin: layout.margin, overlap: layout.overlap, viewport: layout.viewport)
                WallpaperHero(services: services, layout: heroLayout)
            } content: { _ in
                if services.ui.desktopUndo != nil {
                    DesktopUndoBanner(services: services)
                }
                VideosSection(services: services, detailVideo: $detailVideo, ownedOnly: $ownedOnly)
            }
            .overlay {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous)
                        .strokeBorder(DS.Ink.primary, lineWidth: 2)
                        .padding(DS.Space.xs)
                        .allowsHitTesting(false)
                }
            }
            // Videos dropped anywhere on the page join this library.
            .dropDestination(for: URL.self) { urls, _ in
                !store.importVideos(from: urls).isEmpty
            } isTargeted: { isDropTarget = $0 }

            if let video = detailVideo {
                // Dims the page behind the preview; a click anywhere on it goes back.
                Color.black.opacity(0.45)
                    .contentShape(Rectangle())
                    .onTapGesture { withMotion(Motion.standard) { detailVideo = nil } }
                    .transition(.opacity)
                    .accessibilityHidden(true)
                LibraryDetailSheet(video: video, store: store, images: services.images, deleteActions: deleteActions(for: video)) {
                    services.pickWallpaper(.library(video.id))
                    withMotion(Motion.standard) { detailVideo = nil }
                } onClose: {
                    withMotion(Motion.standard) { detailVideo = nil }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Picks up a fresh import without restarting.
        .onAppear { store.reloadLibrary() }
    }

    private func deleteActions(for video: LibraryVideo) -> LibraryTile.DeleteActions {
        LibraryTile.DeleteActions(removeDownload: { await services.wallpaper.offloadAll(only: [video.id]) },
                                  deleteEverywhere: { await services.wallpaper.deleteEverywhere(video.id) })
    }
}

/// The wallpaper on the desktop, playing, as the page's hero: what it is,
/// and the switch and options for it.
private struct WallpaperHero: View {
    let services: AppServices
    let layout: BleedLayout
    /// Plays for a moment when the page opens, then whenever the pointer is on it.
    @State private var isIntroPlaying = true
    @State private var isHovering = false
    /// A brief dip to dark when the wallpaper changes, so the new one fades
    /// up instead of cutting in (one player at a time, never two).
    @State private var dip = 0.0

    var body: some View {
        let store = services.wallpaper
        let config = store.config
        let summary = summary(of: config.source)
        HeroSection(eyebrow: config.isEnabled ? "On your desktop" : "Live wallpaper · Off",
                    title: summary.title, metadata: summary.details, titleRole: .title, bleed: layout) {
            // A preview needn't run at the desktop's frame rate, nor all the
            // time: animating it costs as much as the wallpaper itself.
            WallpaperView(config: { var preview = config; preview.frameRate = min(config.frameRate, 24); return preview }(),
                          services: services)
                .environment(\.widgetIsVisible, isIntroPlaying || isHovering)
                .overlay(Color.black.opacity(dip).allowsHitTesting(false))
                .onChange(of: config.source) {
                    guard !Motion.reducesMotion else { return }
                    dip = 0.85
                    isIntroPlaying = true
                    withAnimation(.easeOut(duration: 0.55).delay(0.08)) { dip = 0 }
                    Task {
                        try? await Task.sleep(for: .seconds(4))
                        isIntroPlaying = false
                    }
                }
        } actions: {
            Button {
                withMotion(Motion.quick) { store.config.isEnabled.toggle() }
            } label: {
                Label(config.isEnabled ? "Turn Off" : "Turn On", systemImage: config.isEnabled ? "pause.fill" : "play.fill")
            }
            .buttonStyle(PillButtonStyle(prominent: !config.isEnabled))
            Button("Options…") { services.openWindow(.wallpaperOptions) }
                .buttonStyle(.pill)
            if case .library(let id) = config.source, store.isFetching(id) {
                HStack(spacing: DS.Space.xs) {
                    ProgressView().controlSize(.small)
                    Text("Downloading from your server…").dsText(.meta)
                    Button("Cancel") { store.cancelFetch(id) }
                        .buttonStyle(.pill)
                        .help("Stop downloading; the default art shows until you pick it again")
                }
            } else if config.isEnabled, !services.ui.wallpaperPlaying {
                Label("Paused to save energy", systemImage: "pause.circle.fill").dsText(.meta)
            }
        }
        .onHover { isHovering = $0 }
        .help("Point at the preview to see it move")
        .task {
            try? await Task.sleep(for: .seconds(6))
            isIntroPlaying = false
        }
    }

    /// What's on the desktop, in a title and a few facts.
    private func summary(of source: WallpaperSource) -> (title: String, details: [String]) {
        switch source {
        case .art(let piece):
            return (piece.style.title, ["Generative art", "\(piece.palette.title) palette", "Animated"])
        case .photo(.web(let photo)):
            return (photo.title ?? "Photo", ["Photo by \(photo.author)", photo.license ?? ""])
        case .photo(.file):
            return ("Your photo", ["With gentle motion"])
        case .photo(.bundled):
            return ("Midnight Aurora", ["Original artwork", "Available offline"])
        case .photo(.art(let piece)):
            return (piece.style.title, ["Still art", "\(piece.palette.title) palette"])
        case .video(let name):
            return ((name as NSString).deletingPathExtension, ["Your video", "Looping silently"])
        case .library(let id):
            guard let video = services.wallpaper.libraryVideo(id) else { return ("A video from your library", []) }
            return (video.title, [video.category.title, video.kind == .image ? "Still" : "Live", video.resolutionLabel,
                                  video.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""])
        }
    }
}

/// Your own videos, then the imported wallpaper library.
private struct VideosSection: View {
    let services: AppServices
    @Binding var detailVideo: LibraryVideo?
    @Binding var ownedOnly: Bool

    /// A video file by name, for the rail.
    private struct VideoFile: Identifiable {
        let id: String
    }

    var body: some View {
        let store = services.wallpaper
        let videos = store.videos
        VStack(alignment: .leading, spacing: DS.Space.section) {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                HStack(alignment: .bottom, spacing: DS.Space.m) {
                    SectionHeader(title: "Your videos",
                                  subtitle: "Any MP4 or MOV loops silently behind your desktop. Drop files on this page or import them.")
                    Button {
                        importVideos()
                    } label: {
                        Label("Import Videos…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.pill)
                }
                if !videos.isEmpty {
                    MediaRail(items: videos.map(VideoFile.init), cardWidth: 280) { file in
                        VideoTile(url: store.videoURL(file.id), isCurrent: store.config.source == .video(file.id)) {
                            services.pickWallpaper(.video(file.id))
                        } onDelete: {
                            store.deleteVideo(file.id)
                        }
                    }
                } else if store.library.isEmpty {
                    EmptyState(symbol: "film.stack", title: "Drop videos here",
                               message: "Screen-sized loops look best. Videos are copied into All Set.",
                               actionTitle: "Import Videos…", action: { importVideos() })
                        .background {
                            RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous)
                                .strokeBorder(DS.Surface.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                        }
                }
            }
            LibrarySection(services: services, detailVideo: $detailVideo, ownedOnly: $ownedOnly)
        }
    }

    private func importVideos() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie]
        panel.prompt = "Import"
        if panel.runModal() == .OK {
            services.wallpaper.importVideos(from: panel.urls)
        }
    }
}

private struct VideoTile: View {
    let url: URL
    let isCurrent: Bool
    let onUse: () -> Void
    let onDelete: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    var body: some View {
        ZStack {
            if isHovering {
                LoopingVideo(url: url, isPlaying: true)
            } else if let thumbnail {
                Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .aspectRatio(16 / 10, contentMode: .fill)
        .frame(minWidth: 0, maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous)
                .strokeBorder(isCurrent ? Color.cyan.opacity(0.8) : Color.white.opacity(0.14), lineWidth: isCurrent ? 1.5 : 1)
        }
        .overlay(alignment: .bottom) {
            if isHovering {
                HStack {
                    Button(action: onUse) {
                        Label(isCurrent ? "Current" : "Set as Wallpaper", systemImage: "photo.artframe")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCurrent)
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                }
                .controlSize(.small)
                .padding(8)
            }
        }
        .onHover { isHovering = $0 }
        .task(id: url) {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 600, height: 600)
            if let (image, _) = try? await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)) {
                thumbnail = NSImage(cgImage: image, size: .zero)
            }
        }
    }
}

/// Videos from a wallpaper library outside All Set (a folder or a drive,
/// imported with `scripts/wallpaper_library.py`). They play from where they
/// live, through the same player and the same pausing rules as any video;
/// cards show a picture made at import, never the video itself until you
/// rest the pointer on one.
private struct LibrarySection: View {
    let services: AppServices
    /// Both owned by `ClassicWallpaperPage`: its bottom detail sheet overlays
    /// the whole page, and needs to agree with the grid on which delete
    /// behaviour applies.
    @Binding var detailVideo: LibraryVideo?
    @Binding var ownedOnly: Bool

    @State private var query = ""
    @State private var category: WallpaperCategory?
    @State private var sort = LibrarySort.title
    @State private var show = Show.all

    /// Moving videos, or stills taken from Wallpaper Engine scenes.
    enum Show: String, CaseIterable, Identifiable {
        case all, live, stills
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: "All"
            case .live: "Live"
            case .stills: "Stills"
            }
        }
    }

    /// Says which copies were checked on the server and which are only expected
    /// there: a configured server isn't a backup until its files are checked.
    static func serverSummary(here: Int, confirmed: Int, expected: Int) -> String {
        var parts = ["\(here) on this Mac"]
        if confirmed > 0 { parts.append("\(confirmed) checked on your server") }
        if expected > 0 { parts.append("\(expected) to download from your server (not checked)") }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        let store = services.wallpaper
        let all = store.library
        if !all.isEmpty {
            let kinds = WallpaperCategory.allCases.filter { kind in all.contains { $0.category == kind } }
            let shown = sort.sorted(all.filter { video in
                (category == nil || video.category == category) && video.matches(query)
                    && (show == .all || (show == .live) == (video.kind == .video))
                    && (!ownedOnly || store.canPlay(video))
            })
            let stills = all.filter { $0.kind == .image }.count
            // Not on this Mac: either checked on the server when this Mac's copy
            // was freed, or only expected there (a server is set up, nothing checked).
            let hasServer = store.config.libraryServerURL != nil
            let locations = all.map(store.copyLocation)
            let confirmed = locations.count { $0 == .confirmedOnServer }
            let expected = locations.count { $0 == .expectedOnServer }
            let onServer = zip(all, locations).filter { $1 == .confirmedOnServer || $1 == .expectedOnServer }.map(\.0)
            // Only the wallpapers with no copy anywhere else need the folder
            // they came from. Once everything has a copy here or on the
            // server, an unplugged drive changes nothing.
            let waiting = zip(all, locations).filter { $1 == .unavailable }.map(\.0)
            let offline = store.libraryRoots.values
                .filter { root in waiting.contains { $0.root == root.id } }
            VStack(alignment: .leading, spacing: DS.Space.m) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        Text("Library").dsText(.section)
                        Text("\(all.count - stills) live, \(stills) stills, "
                             + (!waiting.isEmpty
                                ? "from \(store.libraryRoots.values.compactMap(\.label).sorted().joined(separator: ", "))"
                                : confirmed + expected == 0
                                ? "kept on this Mac"
                                : Self.serverSummary(here: all.count - confirmed - expected, confirmed: confirmed, expected: expected)))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Show", selection: $show) {
                        ForEach(Show.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200)
                    Picker("Sort", selection: $sort) {
                        ForEach(LibrarySort.allCases) { Text($0.title).tag($0) }
                    }
                    .frame(width: 210)
                }
                Label("For your own desktop: these came from Steam Workshop with no author or license. Scene wallpapers are rebuilt here, as a loop made from their own layers or as their artwork held still. Never shared.",
                      systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !offline.isEmpty {
                    Label("\(offline.compactMap(\.label).joined(separator: ", ")) isn't connected. Connect it to preview or play these.",
                          systemImage: "externaldrive.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
                if hasServer, store.serverReachable == false, !onServer.isEmpty {
                    Label("Personal server isn't reachable right now. \(onServer.count) wallpaper\(onServer.count == 1 ? "" : "s") that rely on it won't play until it is.",
                          systemImage: "wifi.slash")
                        .foregroundStyle(.orange)
                }
                if hasServer {
                    FreeUpSpaceRow(store: store)
                }
                HStack(spacing: 8) {
                    TextField("Search your library", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                        .accessibilityIdentifier("wallpaper.library.search")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.xs) {
                            chip(nil, title: "All", symbol: "sparkles")
                            ForEach(kinds) { chip($0, title: $0.title, symbol: $0.symbol) }
                            if hasServer {
                                Divider().frame(height: 16)
                                ownedChip
                            }
                        }
                    }
                }
                if shown.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        ForEach(shown) { video in
                            LibraryTile(video: video, store: store, images: services.images,
                                        isCurrent: store.config.source == .library(video.id), deleteActions: deleteActions(for: video)) {
                                services.pickWallpaper(.library(video.id))
                            } onShowDetails: {
                                withMotion(Motion.responsive) { detailVideo = video }
                            }
                        }
                    }
                }
            }
            .task { store.checkServerReachable() }
        }
    }

    private func deleteActions(for video: LibraryVideo) -> LibraryTile.DeleteActions {
        LibraryTile.DeleteActions(removeDownload: { await services.wallpaper.offloadAll(only: [video.id]) },
                                  deleteEverywhere: { await services.wallpaper.deleteEverywhere(video.id) })
    }

    private var ownedChip: some View {
        Button {
            withMotion(Motion.quick) { ownedOnly.toggle() }
        } label: {
            Label("On This Mac", systemImage: ownedOnly ? "checkmark.circle.fill" : "internaldrive")
                .font(.callout.weight(.medium))
                .foregroundStyle(ownedOnly ? Color.white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(ownedOnly ? Color.accentColor : Color.primary.opacity(0.07)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .help("Only wallpapers stored on this Mac right now. Delete still offers both: Remove Download (this Mac's copy) or Delete Everywhere.")
    }

    private func chip(_ value: WallpaperCategory?, title: String, symbol: String) -> some View {
        let selected = category == value
        return Button {
            withMotion(Motion.quick) { category = value }
        } label: {
            Label(title, systemImage: symbol)
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

/// Deletes this Mac's copy of every wallpaper the personal server is
/// confirmed to hold; each comes back the next time it's played.
private struct FreeUpSpaceRow: View {
    let store: WallpaperStore

    @State private var estimate: (files: Int, bytes: Int64) = (0, 0)
    @State private var confirming = false
    @State private var result: WallpaperStore.OffloadResult?

    var body: some View {
        HStack(spacing: 10) {
            if let progress = store.offloadProgress {
                ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                    .frame(width: 160)
                Text("Checking your server: \(progress.done) of \(progress.total)")
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    Task {
                        estimate = await store.offloadableSpace()
                        confirming = true
                    }
                } label: {
                    Label("Free Up Space…", systemImage: "internaldrive")
                }
                .disabled(store.serverReachable == false)
                Text(result.map(Self.summary)
                     ?? "Wallpapers stay in your library and download again from your server when you use them.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .confirmationDialog(estimate.files == 0 ? "Nothing to free up" : "Free up \(Self.size(estimate.bytes))?",
                            isPresented: $confirming, titleVisibility: .visible) {
            if estimate.files > 0 {
                Button("Free Up \(Self.size(estimate.bytes))", role: .destructive) {
                    Task { result = await store.offloadAll() }
                }
            }
            Button(estimate.files == 0 ? "OK" : "Cancel", role: .cancel) {}
        } message: {
            Text(estimate.files == 0
                 ? "Every wallpaper already plays from your server."
                 : "Each of the \(estimate.files) files is checked on your server first; anything it can't confirm stays on this Mac. Thumbnails stay, so browsing is still instant.")
        }
    }

    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static func summary(_ result: WallpaperStore.OffloadResult) -> String {
        let kept = result.kept.isEmpty ? "" : " \(result.kept.count) kept here: your server couldn't confirm them."
        return "Freed \(size(result.freedBytes)) (\(result.freedFiles) files).\(kept)"
    }
}

private struct LibraryTile: View {
    /// The two ways to delete a wallpaper, offered the same way everywhere: a
    /// filter never changes which one Delete means.
    struct DeleteActions {
        /// This Mac's downloaded copy only: the wallpaper stays in the library and
        /// on the server, and downloads again the next time it's played.
        let removeDownload: @Sendable () async -> WallpaperStore.OffloadResult
        /// Gone everywhere: the server's files and database row, then this Mac.
        /// Gated by Touch ID/the Mac password before it runs at all.
        let deleteEverywhere: @Sendable () async -> WallpaperStore.DeleteEverywhereOutcome?
    }

    let video: LibraryVideo
    let store: WallpaperStore
    let images: ImageLibrary
    let isCurrent: Bool
    let deleteActions: DeleteActions
    let onUse: () -> Void
    let onShowDetails: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    /// Keyboard focus: shows the same controls a hover does.
    @FocusState private var isFocused: Bool
    /// The video starts after a moment's rest, not as the pointer passes over.
    @State private var isPreviewing = false
    @State private var confirmingDelete = false
    @State private var downloadProgress: Double?
    @State private var deleteProblem: String?

    private static let thumbnailPixels = 512

    var body: some View {
        let playable = store.canPlay(video)
        // Not local and no drive for it, but the personal server might still
        // have it: worth trying rather than calling it unplayable outright.
        let onServer = !playable && store.config.libraryServerURL != nil
            && (video.playback != nil || video.still != nil) && store.serverReachable != false
        // Set from the store's own count-of-callers state, not a fetch this
        // tile starts itself: whichever wallpaper is actually downloading (set
        // as active, or another tile's own hover-preview) shows its progress
        // here too, since it's the same shared download either way.
        let isFetching = store.isFetching(video.id)
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ZStack {
                    Rectangle().fill(.quaternary)
                    if let thumbnail {
                        Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
                    }
                    // Resolved only when previewing: finding the file costs a
                    // disk check, too much to do for every card as it scrolls by.
                    // Stills have nothing more to show than their card.
                    if isPreviewing, video.kind == .video {
                        if let url = store.libraryURL(video.id) {
                            LoopingVideo(url: url, isPlaying: true).transition(.opacity)
                        } else {
                            // Not on this Mac: a hover never downloads on its
                            // own (every scroll-by would trigger one) — tap
                            // opens the detail sheet, which does fetch.
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle").font(.title2)
                                Text("Tap to preview").font(.caption2)
                            }
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                            .transition(.opacity)
                        }
                    }
                }
                .scaleEffect(isHovering ? 1.03 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous)
                    .strokeBorder(isCurrent ? Color.cyan.opacity(0.8) : Color.white.opacity(0.14), lineWidth: isCurrent ? 1.5 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isHovering || isFocused || confirmingDelete {
                    Button {
                        confirmingDelete = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.55), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.opacity)
                    .help("Remove the download from this Mac, or delete everywhere")
                    .accessibilityLabel("Delete “\(video.title)”")
                }
            }
            // On the tile, not the hover-only button: moving the pointer to the
            // dialog ends the hover, and a dialog on a view that disappears
            // closes with it.
            .confirmationDialog("Delete “\(video.title)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                if store.canPlay(video) {
                    Button("Remove Download") { runDelete(everywhere: false) }
                }
                Button("Delete Everywhere…", role: .destructive) { runDelete(everywhere: true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(Self.deleteMessage(downloaded: store.canPlay(video)))
            }
            .alert("Couldn't finish deleting “\(video.title)”", isPresented: .init(get: { deleteProblem != nil }, set: { if !$0 { deleteProblem = nil } })) {
                Button("OK") {}
            } message: {
                Text(deleteProblem ?? "")
            }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: video.category.symbol)
                        Text(video.title).lineLimit(1)
                        if video.kind == .image {
                            Image(systemName: "photo")
                                .foregroundStyle(.white.opacity(0.75))
                                .help("A still from the scene: its animation isn't included")
                        }
                        Spacer(minLength: 4)
                        Text(video.resolutionLabel).foregroundStyle(.white.opacity(0.75))
                        if let size = video.size {
                            Text("·").foregroundStyle(.white.opacity(0.5))
                            Text(Self.size(size)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    .font(.caption.weight(.semibold))
                    if isFetching {
                        ProgressView(value: downloadProgress ?? 0)
                            .tint(.white)
                        HStack {
                            Text(downloadProgress.map { "Downloading… \(Int($0 * 100))%" } ?? "Downloading…")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer(minLength: 4)
                            Button("Cancel") { store.cancelFetch(video.id) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .help("Stop downloading this wallpaper")
                        }
                    } else if isHovering {
                        Button(action: onUse) {
                            Label(isCurrent ? "Current" : playable ? "Set as Wallpaper"
                                  : onServer ? "Fetch from Server" : "Drive Not Connected",
                                  systemImage: "photo.artframe")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isCurrent || !(playable || onServer))
                    }
                }
                .foregroundStyle(.white)
                .padding(8)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture(perform: onShowDetails)
            // Without a pointer too: Return or Space opens it, Delete offers the delete choices.
            .keyboardActivatable(hint: "Shows details", activate: onShowDetails, delete: { confirmingDelete = true })
            .focused($isFocused)
            .onHover { hovering in
                withMotion(Motion.quick) { isHovering = hovering }
                if !hovering { isPreviewing = false }
            }
            .task(id: isHovering) {
                guard isHovering else { return }
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, isHovering else { return }
                withMotion(Motion.standard) { isPreviewing = true }
            }
            .task(id: video.id) {
                guard let file = store.libraryThumbnailURL(video) else { return }
                if let cached = images.cachedThumbnail(at: file, maxPixels: Self.thumbnailPixels) {
                    thumbnail = cached
                    return
                }
                // Not on this Mac: bring it back from the personal server
                // first. Only tiles actually on screen get here (the grid
                // is lazy), so this never asks for all of them at once.
                if store.config.libraryServerURL != nil, !FileManager.default.fileExists(atPath: file.path) {
                    _ = try? await store.fetchThumbnail(video.id)
                }
                thumbnail = await images.thumbnail(at: file, maxPixels: Self.thumbnailPixels)
            }
            // A local timer, not Observation: `fetches` ticks 4 times a
            // second, and only this one tile — not every tile watching
            // `isFetching` — should redraw that often.
            .task(id: isFetching) {
                guard isFetching else { downloadProgress = nil; return }
                while !Task.isCancelled {
                    downloadProgress = store.fetchProgress(for: video.id)
                    try? await Task.sleep(for: .milliseconds(150))
                }
            }
            .help(video.statusReason.map { "\(video.title): personal use (\($0))" } ?? video.title)
    }

    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func deleteMessage(downloaded: Bool) -> String {
        (downloaded ? "Remove Download frees this Mac's copy only after your server's copy is checked to be the same file; it stays in your library and downloads again when played. " : "")
            + "Delete Everywhere removes it from your server, the database and this Mac. It asks to confirm it's you, and can't be undone."
    }

    private func runDelete(everywhere: Bool) {
        guard everywhere else {
            Task { _ = await deleteActions.removeDownload() }
            return
        }
        Task {
            guard await AdminGate.authorize(reason: "delete “\(video.title)” everywhere") else { return }
            switch await deleteActions.deleteEverywhere() {
            case .success, nil: break
            case .notDeleted(let reason):
                    deleteProblem = reason + " Nothing was deleted: it's still on this Mac and in your library. Delete it again once that's fixed."
                case .deletedOnServer(let reason):
                    deleteProblem = "It's gone from your server, but this Mac's copy couldn't be fully removed (" + reason + "). Delete it again to finish."
            }
        }
    }
}

/// A bigger look at one wallpaper, sliding up over the grid: a real
/// preview (fetching it if it isn't local — tapping is deliberate, unlike
/// a hover) plus every detail the tile's small footer has no room for.
private struct LibraryDetailSheet: View {
    let video: LibraryVideo
    let store: WallpaperStore
    let images: ImageLibrary
    let deleteActions: LibraryTile.DeleteActions
    let onUse: () -> Void
    let onClose: () -> Void

    @State private var thumbnail: NSImage?
    /// A local still, decoded off the main thread at a size the sheet can
    /// use: the original is 3840 px, and drawing it straight from the file
    /// decoded all of it on the main thread as the sheet slid in.
    @State private var still: NSImage?
    @State private var confirmingDelete = false
    @State private var deleteProblem: String?

    var body: some View {
        let isFetching = store.isFetching(video.id)
        let url = store.libraryURL(video.id)
        VStack(spacing: 0) {
            ZStack {
                Rectangle().fill(.quaternary)
                if let thumbnail { Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill) }
                if let url {
                    if video.kind == .image {
                        if let still { Image(nsImage: still).resizable().aspectRatio(contentMode: .fill) }
                    } else {
                        LoopingVideo(url: url, isPlaying: true)
                    }
                } else if isFetching {
                    VStack(spacing: 10) {
                        ProgressView().controlSize(.large).tint(.white)
                        Button("Cancel Download") { store.cancelFetch(video.id) }
                            .buttonStyle(.bordered)
                    }
                } else if store.cancelledFetches.contains(video.id) {
                    Button("Download Again", systemImage: "arrow.down.circle") {
                        store.allowFetch(video.id)
                        Task { await store.fetchLibraryVideoRetrying(video.id, delays: [.seconds(2)]) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(height: 320)
            .clipped()
            .overlay(alignment: .topTrailing) {
                // Always in view, over the preview, and Esc does the same.
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.55), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                }
                .buttonStyle(PressableStyle())
                .keyboardShortcut(.cancelAction)
                .help("Close the preview (Esc)")
                .accessibilityLabel("Close preview")
                .padding(12)
            }
            .task(id: url) {
                guard video.kind == .image, let url else { return }
                still = images.cachedThumbnail(at: url, maxPixels: 1600)
                if still == nil { still = await images.thumbnail(at: url, maxPixels: 1600) }
            }
            .task(id: video.id) {
                guard url == nil, let file = store.libraryThumbnailURL(video) else { return }
                if let cached = images.cachedThumbnail(at: file, maxPixels: 1024) {
                    thumbnail = cached
                } else {
                    thumbnail = await images.thumbnail(at: file, maxPixels: 1024)
                }
            }
            .task(id: video.id) {
                guard url == nil, store.config.libraryServerURL != nil else { return }
                // Opening the preview is asking for it, even after a cancel.
                store.allowFetch(video.id)
                await store.fetchLibraryVideoRetrying(video.id, delays: [.seconds(2)])
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title).font(.title2.bold())
                        Text(video.category.title).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], alignment: .leading, spacing: 8) {
                    detail("Resolution", video.resolutionLabel)
                    if let size = video.size { detail("Size", Self.size(size)) }
                    if let duration = video.duration { detail("Length", String(format: "%.0fs", duration)) }
                    if let fps = video.fps { detail("Frame rate", String(format: "%.0f fps", fps)) }
                    detail("Kind", video.kind == .image ? "Still" : "Live")
                }
                if let reason = video.statusReason {
                    Label(reason, systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button(action: onUse) {
                        Label(store.config.source == .library(video.id) ? "Current" : "Set as Wallpaper", systemImage: "photo.artframe")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.config.source == .library(video.id))
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete…", systemImage: "trash")
                    }
                    Spacer()
                }
            }
            .padding(20)
        }
        .frame(maxWidth: 640)
        .background(DS.Surface.canvasLift, in: RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous).strokeBorder(DS.Surface.hairline))
        .background(CardHalo(spread: .shadow).foregroundStyle(.black).opacity(0.35))
        .padding(24)
        .confirmationDialog("Delete “\(video.title)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            if store.canPlay(video) {
                Button("Remove Download") { runDelete(everywhere: false) }
            }
            Button("Delete Everywhere…", role: .destructive) { runDelete(everywhere: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(LibraryTile.deleteMessage(downloaded: store.canPlay(video)))
        }
        .alert("Couldn't finish deleting “\(video.title)”", isPresented: .init(get: { deleteProblem != nil }, set: { if !$0 { deleteProblem = nil } })) {
            Button("OK") {}
        } message: {
            Text(deleteProblem ?? "")
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium))
        }
    }

    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func runDelete(everywhere: Bool) {
        guard everywhere else {
            Task { _ = await deleteActions.removeDownload(); onClose() }
            return
        }
        Task {
            guard await AdminGate.authorize(reason: "delete “\(video.title)” everywhere") else { return }
            switch await deleteActions.deleteEverywhere() {
            case .success, nil: onClose()
            case .notDeleted(let reason):
                    deleteProblem = reason + " Nothing was deleted: it's still on this Mac and in your library. Delete it again once that's fixed."
                case .deletedOnServer(let reason):
                    deleteProblem = "It's gone from your server, but this Mac's copy couldn't be fully removed (" + reason + "). Delete it again to finish."
            }
        }
    }
}

/// Look, motion and energy settings for the live wallpaper.
struct WallpaperOptionsPage: View {
    let services: AppServices

    var body: some View {
        let store = services.wallpaper
        FormPage(eyebrow: "Desktop", title: "Wallpaper Options",
                 subtitle: "How the live wallpaper looks, moves and saves energy.") {
            Section {
                Toggle("Live wallpaper", isOn: binding(\.isEnabled))
                LabeledContent("Dim") {
                    Slider(value: binding(\.dim), in: 0...0.6)
                        .frame(width: 220)
                }
            } footer: {
                Text("Dimming helps desktop icons and widgets stand out.")
            }

            Section("Art") {
                LabeledContent("Speed") {
                    Slider(value: binding(\.speed), in: 0.25...3)
                        .frame(width: 220)
                }
                Picker("Quality", selection: binding(\.sharpArt)) {
                    Text("Balanced: soft styles look the same, much less work").tag(false)
                    Text("Sharp: full resolution").tag(true)
                }
                Picker("Frame rate", selection: binding(\.frameRate)) {
                    Text("15 fps: calm, least energy").tag(15)
                    Text("30 fps: smooth").tag(30)
                    Text("60 fps: silky").tag(60)
                }
            }

            Section("Photos") {
                Picker("Motion", selection: binding(\.motion)) {
                    ForEach(WallpaperMotion.allCases) { motion in
                        Text(motion.title).tag(motion)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Pause while windows cover the desktop", isOn: binding(\.pauseWhenCovered))
                Toggle("Pause on battery power", isOn: binding(\.pauseOnBattery))
            } header: {
                Text("Energy")
            } footer: {
                Text("The wallpaper always pauses while an app is full screen, when the screen is locked or asleep, and in Low Power Mode.")
            }

            Section {
                Toggle("Match the system wallpaper", isOn: binding(\.matchSystemWallpaper))
            } footer: {
                Text("Sets a still of your live wallpaper as the macOS wallpaper, so Mission Control, Spaces and the lock screen match. Your previous wallpaper comes back when you turn the live wallpaper off.")
            }

            Section {
                Button("Choose a Wallpaper…") { services.openWindow(.wallpaper) }
            }
        }
        .motion(Motion.standard, value: store.config)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<WallpaperConfig, Value>) -> Binding<Value> {
        Binding(get: { services.wallpaper.config[keyPath: keyPath] },
                set: { services.wallpaper.config[keyPath: keyPath] = $0 })
    }
}
