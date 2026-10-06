import AllSetCore
import AppKit
import AVFoundation
import OSLog
import SwiftUI

/// A full-screen window at the desktop level: above the system wallpaper,
/// below desktop icons and widgets, never taking a click.
/// Whether one screen's wallpaper should move.
@Observable @MainActor
final class WallpaperScreenState {
    var isPlaying = true
}

final class WallpaperWindow: NSWindow {
    let state = WallpaperScreenState()

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        ignoresMouseEvents = true
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Runs the live wallpaper: one window per screen, playing only when it can be
/// seen and the Mac isn't saving power, and keeping the system wallpaper in step.
@MainActor
final class WallpaperController {
    private let services: AppServices
    private var windows: [String: WallpaperWindow] = [:]
    private var observers: [NSObjectProtocol] = []
    /// Each window's occlusion observer, removed with the window.
    private var occlusionObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
    private var isLocked = false
    private var isAsleep = false
    private var appliedSystemSource: WallpaperSource?
    private let log = Logger(subsystem: "com.pratik.allset", category: "wallpaper")

    init(services: AppServices) {
        self.services = services
    }

    func start() {
        sync()
        observe({ [services] in services.wallpaper.config }) { [weak self] _ in self?.sync() }
        observe({ [services] in services.ui.performance }) { [weak self] _ in self?.updatePlayback() }
        // A library wallpaper downloaded after the fact: its still for the
        // lock screen and Mission Control couldn't be made while it was missing.
        observe({ [services] in services.wallpaper.fetchGeneration }) { [weak self] _ in
            guard let self, services.wallpaper.config.isEnabled, services.wallpaper.config.matchSystemWallpaper else { return }
            self.matchSystemWallpaper(to: services.wallpaper.config.source)
        }

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.sync() } })
        observers.append(workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isAsleep = true; self?.updatePlayback() }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isAsleep = false; self?.updatePlayback() }
        })
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isLocked = true; self?.updatePlayback() }
        })
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isLocked = false; self?.updatePlayback() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePlayback() }
        })
        // A library's drive coming or going changes what can play.
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.services.wallpaper.refreshLibraryReachability() }
            })
        }
        // Switching apps usually changes what covers the desktop.
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePlayback() }
        })
    }

    private func sync() {
        let config = services.wallpaper.config
        guard config.isEnabled else {
            windows.values.forEach(closeWindow)
            windows.removeAll()
            restoreSystemWallpapers()
            return
        }

        // One window per display, by its id: two monitors of the same model
        // share a name, and keyed by name one of them had no wallpaper.
        let screens = Dictionary(NSScreen.screens.map { ($0.stableID, $0) }, uniquingKeysWith: { first, _ in first })
        for key in windows.keys where screens[key] == nil {
            if let window = windows.removeValue(forKey: key) { closeWindow(window) }
        }
        for (key, screen) in screens {
            let window = windows[key] ?? makeWindow(for: screen)
            windows[key] = window
            if window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
            window.orderFront(nil)
        }
        updatePlayback()
        if config.matchSystemWallpaper {
            matchSystemWallpaper(to: config.source)
        } else {
            restoreSystemWallpapers()
        }
    }

    private func makeWindow(for screen: NSScreen) -> WallpaperWindow {
        let window = WallpaperWindow(screen: screen)
        let view = NSHostingView(rootView: WallpaperRoot(services: services, state: window.state))
        view.sizingOptions = []
        window.contentView = view
        occlusionObservers[ObjectIdentifier(window)] = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.updatePlayback() } }
        return window
    }

    private func closeWindow(_ window: WallpaperWindow) {
        if let observer = occlusionObservers.removeValue(forKey: ObjectIdentifier(window)) {
            NotificationCenter.default.removeObserver(observer)
        }
        window.close()
    }

    /// Plays each screen only when someone could see it and it isn't wasting
    /// power. "Covered" means windows hide nearly all of that screen's desktop,
    /// not just every last pixel: a strip of desktop by the Dock isn't worth
    /// decoding a 4K video or drawing art 30 times a second for.
    private func updatePlayback() {
        let config = services.wallpaper.config
        let policy = services.ui.performance
        let allowed = config.isEnabled
            && !isLocked && !isAsleep
            && !policy.pausesDecorativeMotion
            && !(config.pauseOnBattery && policy.isOnBattery)
        let covering = allowed && config.pauseWhenCovered ? DesktopCoverage.windowRects() : []
        var anyPlaying = false
        for window in windows.values {
            var playing = allowed
            if playing {
                // A full-screen app gets its own Space, which marks this window occluded.
                playing = window.occlusionState.contains(.visible)
                if playing, config.pauseWhenCovered {
                    playing = DesktopCoverage.uncoveredFraction(of: window.frame, by: covering) >= Self.minimumUncovered
                }
            }
            if window.state.isPlaying != playing { window.state.isPlaying = playing }
            anyPlaying = anyPlaying || playing
        }
        if services.ui.wallpaperPlaying != anyPlaying {
            services.ui.wallpaperPlaying = anyPlaying
        }
        scheduleCoverageCheck(active: allowed && config.pauseWhenCovered && moves(config))
    }

    /// Whether the wallpaper has any motion to pause. A still photo looks the
    /// same playing or not, so there's no need to keep checking what covers it.
    private func moves(_ config: WallpaperConfig) -> Bool {
        switch config.source {
        case .art, .video: true
        case .library(let id):
            // A still from a library moves only as a photo does.
            services.wallpaper.libraryVideo(id)?.kind != .image || config.motion != .still
        case .photo(let source):
            if case .art = source { true } else { config.motion != .still }
        }
    }

    /// How much of a screen's desktop must show for its wallpaper to move.
    private static var minimumUncovered: Double {
        #if DEBUG
        // `-minimumUncovered 0`: the old rule (move while any of it shows), for comparing.
        if let value = UserDefaults.standard.object(forKey: "minimumUncovered") as? Double { return value }
        if let text = UserDefaults.standard.string(forKey: "minimumUncovered"), let value = Double(text) { return value }
        #endif
        return 0.15
    }

    /// Windows move without telling the wallpaper, so while pausing when
    /// covered, it looks again every couple of seconds (about a millisecond each).
    private var coverageTimer: Timer?

    private func scheduleCoverageCheck(active: Bool) {
        guard active else {
            coverageTimer?.invalidate()
            coverageTimer = nil
            return
        }
        guard coverageTimer == nil else { return }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePlayback() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        coverageTimer = timer
    }

    // MARK: System wallpaper

    /// Sets a still of the live wallpaper as the system one, remembering the
    /// user's original first.
    private func matchSystemWallpaper(to source: WallpaperSource) {
        guard appliedSystemSource != source else { return }
        // Already showing the still made for this wallpaper (from an earlier
        // launch): drawing, encoding and writing it again would change nothing.
        if let key = Self.stillKey(source), UserDefaults.standard.string(forKey: Self.stillSourceKey) == key,
           let path = UserDefaults.standard.string(forKey: Self.stillPathKey), FileManager.default.fileExists(atPath: path),
           NSScreen.screens.allSatisfy({ NSWorkspace.shared.desktopImageURL(for: $0)?.path == path }) {
            appliedSystemSource = source
            return
        }
        // Claimed before the work starts: remembering the original below
        // changes the settings, which calls this again, and a second pass
        // would delete the still the first had just set.
        appliedSystemSource = source
        Task {
            guard let still = await stillImage(for: source) else {
                if appliedSystemSource == source { appliedSystemSource = nil }
                return
            }
            // A newer choice has taken over.
            guard appliedSystemSource == source else { return }
            UserDefaults.standard.set(Self.stillKey(source), forKey: Self.stillSourceKey)
            UserDefaults.standard.set(still.path, forKey: Self.stillPathKey)
            for screen in NSScreen.screens {
                if DisplayIdentity.value(in: services.wallpaper.config.originalWallpapers, for: screen.displayInfo) == nil,
                   let current = NSWorkspace.shared.desktopImageURL(for: screen),
                   !current.path.hasPrefix(services.wallpaper.directory.path) {
                    services.wallpaper.config.originalWallpapers[screen.stableID] = current
                }
                do {
                    try NSWorkspace.shared.setDesktopImageURL(still, for: screen, options: [:])
                } catch {
                    log.error("Couldn't set the system wallpaper: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    /// Which wallpaper the system still was last made from, and where it is.
    private static let stillSourceKey = "wallpaper.still.source"
    private static let stillPathKey = "wallpaper.still.path"

    private static func stillKey(_ source: WallpaperSource) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(source)).map { String(decoding: $0, as: UTF8.self) }
    }

    private func restoreSystemWallpapers() {
        let originals = services.wallpaper.config.originalWallpapers
        guard !originals.isEmpty else { return }
        for screen in NSScreen.screens {
            guard let url = DisplayIdentity.value(in: originals, for: screen.displayInfo),
                  FileManager.default.fileExists(atPath: url.path) else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        }
        services.wallpaper.config.originalWallpapers = [:]
        appliedSystemSource = nil
    }

    /// A PNG of the wallpaper as it looks right now, sized for the main screen.
    private func stillImage(for source: WallpaperSource) async -> URL? {
        let size = NSScreen.screens.first?.frame.size ?? CGSize(width: 1470, height: 956)
        // A new name each time, since macOS ignores a changed file with the same name.
        let file = services.wallpaper.directory.appendingPathComponent("still-\(UUID().uuidString.prefix(8)).png")
        cleanUpOldStills()
        switch source {
        case .art(let piece):
            // Drawing has to happen here; encoding and writing don't.
            let renderer = ImageRenderer(content: ArtView(piece: piece).frame(width: size.width, height: size.height))
            renderer.scale = 2
            guard let image = renderer.cgImage else { return nil }
            return await Task.detached(priority: .utility) { Self.writePNG(image, to: file) ? file : nil }.value
        case .photo(let imageSource):
            if case .art(let piece) = imageSource {
                return await stillImage(for: .art(piece))
            }
            // The file is all the system wallpaper needs: no decode.
            return await services.images.availableFile(for: imageSource)
        case .video(let name):
            return await videoStill(services.wallpaper.videoURL(name), to: file)
        case .library(let id):
            guard let url = services.wallpaper.libraryURL(id) else { return nil }
            // A still is already a picture: the system wallpaper can use it as it is.
            if services.wallpaper.libraryVideo(id)?.kind == .image { return url }
            return await videoStill(url, to: file)
        }
    }

    /// A frame from a video, a moment in, written as a PNG.
    private func videoStill(_ url: URL, to file: URL) async -> URL? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        // A moment in, past any fade from black.
        generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)
        var frame = try? await generator.image(at: CMTime(seconds: 2, preferredTimescale: 600))
        if frame == nil { frame = try? await generator.image(at: .zero) }
        guard let (image, _) = frame else { return nil }
        return await Task.detached(priority: .utility) { Self.writePNG(image, to: file) ? file : nil }.value
    }

    /// Encodes and writes a PNG; false (and logged) if it couldn't.
    private nonisolated static func writePNG(_ image: CGImage, to file: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        let written = CGImageDestinationFinalize(destination)
        if !written { Logger(subsystem: "com.pratik.allset", category: "wallpaper").error("Couldn't write the wallpaper still") }
        return written
    }

    private func cleanUpOldStills() {
        let folder = services.wallpaper.directory
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("still-") {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: Views

private struct WallpaperRoot: View {
    let services: AppServices
    let state: WallpaperScreenState

    /// Off the charger (or when warm) drawn art runs at the policy's art rate,
    /// the same 15 frames a second widgets' art already keeps to: soft,
    /// slow-moving art looks the same and the GPU does half the work.
    private var config: WallpaperConfig {
        var config = services.wallpaper.config
        let policy = services.ui.performance
        if policy.tier >= .balanced { config.frameRate = min(config.frameRate, policy.artFrameRate) }
        return config
    }

    var body: some View {
        WallpaperView(config: config, services: services)
            .environment(\.widgetIsVisible, state.isPlaying)
            .ignoresSafeArea()
    }
}

/// The wallpaper itself; also used, scaled down, as the preview in the app.
struct WallpaperView: View {
    let config: WallpaperConfig
    let services: AppServices
    @Environment(\.widgetIsVisible) private var isPlaying
    @State private var downloadProgress: Double?

    var body: some View {
        ZStack {
            Color.black
            switch config.source {
            case .art(let piece):
                if config.sharpArt {
                    ArtView(piece: piece, animated: true, speed: config.speed, frameRate: config.frameRate)
                } else {
                    GeometryReader { geometry in
                        ArtView(piece: piece, animated: true, speed: config.speed, frameRate: config.frameRate)
                            .frame(width: geometry.size.width / 2, height: geometry.size.height / 2)
                            .scaleEffect(2, anchor: .topLeading)
                    }
                }
            case .photo(let source):
                MovingPhoto(source: source, motion: config.motion, library: services.images)
            case .video(let name):
                LoopingVideo(url: services.wallpaper.videoURL(name), isPlaying: isPlaying)
            case .library(let id):
                // Read here, not only in the "missing" branch, so a download
                // starting and finishing redraws this view and libraryURL(id)
                // (a raw file check Observation can't see) is asked again. It
                // changes only then, never per progress tick.
                let isFetching = services.wallpaper.isFetching(id)
                // Same player (or, for a still, the same slow motion as a
                // photo) and the same pausing rules as any other wallpaper.
                if let url = services.wallpaper.libraryURL(id) {
                    if services.wallpaper.libraryVideo(id)?.kind == .image {
                        MovingStill(url: url, motion: config.motion)
                    } else {
                        LoopingVideo(url: url, isPlaying: isPlaying)
                    }
                } else {
                    // Its drive isn't connected, and it isn't on this Mac:
                    // the default art while a fetch from the personal server
                    // (if one's configured) tries to bring it back.
                    //
                    // Keyed on hasLoadedLibrary, not just id: the very first
                    // render can happen before the catalog finishes loading
                    // (it loads asynchronously), and without this the fetch
                    // would spuriously fail then - "no server", really "no
                    // catalog yet" - and never retry once real data arrives,
                    // since .task(id:) only reruns when its id changes. The
                    // fetch itself retries with growing pauses, so a server or
                    // Tailscale that comes up late (at login) still wins.
                    ZStack(alignment: .bottomTrailing) {
                        ArtView(piece: ArtPiece(style: .aurora, palette: .aurora), animated: true, speed: config.speed,
                                frameRate: config.frameRate)
                        if isFetching {
                            VStack(spacing: 4) {
                                ProgressView(value: downloadProgress ?? 0).frame(width: 120)
                                Text(downloadProgress.map { "\(Int($0 * 100))%" } ?? "Starting…")
                                    .font(.caption2).foregroundStyle(.white.opacity(0.85))
                            }
                            .padding(16)
                            // A local timer, not Observation: `fetches` ticks 4
                            // times a second, too often to redraw this view on.
                            .task(id: isFetching) {
                                while !Task.isCancelled {
                                    downloadProgress = services.wallpaper.fetchProgress(for: id)
                                    try? await Task.sleep(for: .milliseconds(150))
                                }
                            }
                        }
                    }
                    // The cancelled flag is part of the id too: picking the
                    // wallpaper again after a Cancel clears it, which reruns
                    // this and downloads it.
                    .task(id: "\(id)#\(services.wallpaper.hasLoadedLibrary)#\(services.wallpaper.cancelledFetches.contains(id))") {
                        await services.wallpaper.fetchLibraryVideoRetrying(id)
                    }
                }
            }
            Color.black.opacity(config.dim)
        }
        .clipped()
    }
}

/// A photo that drifts or breathes slowly, like a film pan. Core Animation
/// runs the motion, so it costs the app nothing while it plays.
private struct MovingPhoto: View {
    let source: ImageSource
    let motion: WallpaperMotion
    let library: ImageLibrary

    @State private var image: CGImage?
    @Environment(\.widgetIsVisible) private var isPlaying

    var body: some View {
        Group {
            if case .art = source {
                // Generated art animates itself.
                PhotoContent(source: source, filter: .none, tint: .accentColor, animated: isPlaying, library: library)
            } else if let image {
                DriftingImage(image: image, motion: isPlaying ? driftMotion : .still,
                              period: motion == .drift ? 45 : 18)
            } else {
                Color.black
            }
        }
        .task(id: source) {
            guard let loaded = await library.image(for: source) else { return }
            image = loaded.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    }

    private var driftMotion: DriftingImage.Motion {
        switch motion {
        case .still: .still
        case .drift: .pan
        case .breathe: .breathe
        }
    }
}

/// A picture file (a library still) with a photo wallpaper's slow motion:
/// decoded off the main thread at screen size, moved by Core Animation.
private struct MovingStill: View {
    let url: URL
    let motion: WallpaperMotion

    @State private var image: CGImage?
    @Environment(\.widgetIsVisible) private var isPlaying

    var body: some View {
        Group {
            if let image {
                DriftingImage(image: image, motion: isPlaying ? driftMotion : .still, period: motion == .drift ? 45 : 18)
            } else {
                Color.black
            }
        }
        .task(id: url) {
            image = await Task.detached(priority: .userInitiated) { [url] () -> SendableImage? in
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let picture = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                          kCGImageSourceCreateThumbnailFromImageAlways: true,
                          kCGImageSourceCreateThumbnailWithTransform: true,
                          kCGImageSourceThumbnailMaxPixelSize: 3840,
                      ] as CFDictionary)
                else { return nil }
                return SendableImage(ImageLibrary.displayReady(picture))
            }.value?.image
        }
    }

    private var driftMotion: DriftingImage.Motion {
        switch motion {
        case .still: .still
        case .drift: .pan
        case .breathe: .breathe
        }
    }
}

/// A muted, endlessly looping video, filling the screen. Screens showing the
/// same video share one player, so a 4K file is decoded once, not per screen;
/// it plays while any of them wants it to.
struct LoopingVideo: NSViewRepresentable {
    let url: URL
    let isPlaying: Bool

    final class PlayerView: NSView {
        let playerLayer = AVPlayerLayer()
        var url: URL?

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            playerLayer.videoGravity = .resizeAspectFill
            layer = playerLayer
        }

        required init?(coder: NSCoder) { nil }
    }

    func makeNSView(context: Context) -> PlayerView {
        let view = PlayerView(frame: .zero)
        update(view)
        return view
    }

    func updateNSView(_ view: PlayerView, context: Context) {
        update(view)
    }

    static func dismantleNSView(_ view: PlayerView, coordinator: ()) {
        if let url = view.url { SharedVideoPlayers.release(url, viewer: ObjectIdentifier(view)) }
        view.playerLayer.player = nil
    }

    private func update(_ view: PlayerView) {
        let viewer = ObjectIdentifier(view)
        if view.url != url {
            if let old = view.url { SharedVideoPlayers.release(old, viewer: viewer) }
            view.url = url
            view.playerLayer.player = SharedVideoPlayers.player(for: url)
        }
        SharedVideoPlayers.set(isPlaying, url: url, viewer: viewer)
    }
}

/// One looping player per video file, shared by every screen showing it.
@MainActor
enum SharedVideoPlayers {
    private final class Entry {
        let player = AVQueuePlayer()
        var looper: AVPlayerLooper?
        /// Each view showing it, and whether that view wants it moving.
        var viewers: [ObjectIdentifier: Bool] = [:]
    }

    private static var entries: [URL: Entry] = [:]

    #if DEBUG
    /// Players alive, and how many views hold each (for probes).
    static var debugReport: String {
        "players \(entries.count) (viewers \(entries.values.map { $0.viewers.count }.reduce(0, +)))"
    }
    #endif

    static func player(for url: URL) -> AVQueuePlayer {
        if let entry = entries[url] { return entry.player }
        let entry = Entry()
        entry.player.isMuted = true
        entry.player.preventsDisplaySleepDuringVideoPlayback = false
        entry.looper = AVPlayerLooper(player: entry.player, templateItem: AVPlayerItem(url: url))
        entries[url] = entry
        return entry.player
    }

    static func set(_ playing: Bool, url: URL, viewer: ObjectIdentifier) {
        guard let entry = entries[url] else { return }
        entry.viewers[viewer] = playing
        apply(entry)
    }

    static func release(_ url: URL, viewer: ObjectIdentifier) {
        guard let entry = entries[url] else { return }
        entry.viewers[viewer] = nil
        if entry.viewers.isEmpty {
            entry.player.pause()
            entry.player.removeAllItems()
            entries[url] = nil
        } else {
            apply(entry)
        }
    }

    private static func apply(_ entry: Entry) {
        let wanted = entry.viewers.values.contains(true)
        if wanted, entry.player.rate == 0 { entry.player.play() }
        if !wanted, entry.player.rate != 0 { entry.player.pause() }
    }
}
