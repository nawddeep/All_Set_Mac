import AllSetCore
import AppKit
import AVFoundation
import OSLog
import SwiftUI

/// A picture file (a library still) with a photo wallpaper's slow motion:
/// decoded off the main thread at screen size, moved by Core Animation.
struct MovingStill: View {
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
