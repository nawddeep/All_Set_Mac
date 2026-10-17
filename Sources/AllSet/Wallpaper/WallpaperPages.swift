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
                let videos = urls.filter(WallpaperStore.isVideo)
                Task { await store.importVideos(from: videos) }
                return !videos.isEmpty
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

    private func deleteActions(for video: LibraryVideo) -> WallpaperLibraryTile.DeleteActions {
        WallpaperLibraryTile.DeleteActions(removeDownload: { await services.wallpaper.offloadAll(only: [video.id]) },
                                  deleteEverywhere: { await services.wallpaper.deleteEverywhere(video.id) })
    }
}

/// The wallpaper on the desktop, playing, as the page's hero: what it is,
/// and the switch and options for it.
struct WallpaperHero: View {
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

/// The live wallpapers that come with All Set, a rail per mood. First on the
/// page, so a new install has plenty to pick from with nothing imported.
struct BuiltInSection: View {
    let services: AppServices

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(title: "Built in",
                          subtitle: "\(BuiltInWallpaper.all.count) live wallpapers drawn on your Mac. Point at one to see it move.")
            ForEach(BuiltInWallpaper.Category.allCases) { category in
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(category.title).dsText(.headline)
                    MediaRail(items: BuiltInWallpaper.inCategory(category), cardWidth: 220) { wallpaper in
                        BuiltInTile(wallpaper: wallpaper,
                                    isCurrent: services.wallpaper.config.source == wallpaper.source) {
                            services.pickWallpaper(wallpaper.source)
                        }
                    }
                }
            }
        }
    }
}

/// One built-in wallpaper: still until the pointer rests on it.
struct BuiltInTile: View {
    let wallpaper: BuiltInWallpaper
    let isCurrent: Bool
    let onUse: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onUse) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                // A picture drawn once and kept: scrolling past a tile costs a
                // bitmap, not a Canvas redraw. The live art runs only under the pointer.
                Group {
                    if isHovering {
                        ArtView(piece: wallpaper.piece, animated: true, frameRate: 24)
                    } else {
                        Image(nsImage: BuiltInStills.image(for: wallpaper.piece))
                            .resizable()
                    }
                }
                    .frame(width: 220, height: 138)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous)
                            .strokeBorder(isCurrent ? Color.cyan.opacity(0.8) : Color.white.opacity(0.14), lineWidth: isCurrent ? 1.5 : 1)
                    }
                Text(wallpaper.name).dsText(.body).lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 220, height: 162, alignment: .top)
        .onHover { isHovering = $0 }
        .help(isCurrent ? "On your desktop now" : "Set \(wallpaper.name) as your wallpaper")
        .accessibilityLabel(wallpaper.name)
        .accessibilityValue(isCurrent ? "Current wallpaper" : "")
        .accessibilityHint("Sets it as your wallpaper")
    }
}

/// Still pictures of the built-in wallpapers, drawn once per launch at tile size.
@MainActor
enum BuiltInStills {
    private static var images: [String: NSImage] = [:]

    static func image(for piece: ArtPiece) -> NSImage {
        if let image = images[piece.id] { return image }
        let renderer = ImageRenderer(content: ArtView(piece: piece).frame(width: 220, height: 138))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: CGSize(width: 220, height: 138))
        images[piece.id] = image
        return image
    }
}

/// Your own videos, then the imported wallpaper library.
struct VideosSection: View {
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
            BuiltInSection(services: services)
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
                    EmptyState(symbol: "film.stack", title: "Add your own videos",
                               message: "Drop MP4 or MOV files here. Screen-sized loops look best. Videos are copied into All Set.",
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
            let urls = panel.urls
            Task { await services.wallpaper.importVideos(from: urls) }
        }
    }
}

struct VideoTile: View {
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
