import AllSetCore
import SwiftUI

struct HomeTab: View {
    let services: AppServices

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            NowPlayingCard(media: services.media)
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 6)
            QuickStats(monitor: services.monitor, settings: services.settings)
                .frame(width: 244)
        }
    }
}

struct NowPlayingCard: View {
    let media: MediaController
    @State private var artworkHovered = false

    var body: some View {
        if let info = media.info {
            let accent = media.accentColor.map { Color(nsColor: $0) } ?? .white
            HStack(spacing: 16) {
                Button(action: media.openSourceApp) {
                    // Like the iPhone: the artwork sits back a little while paused.
                    ArtworkView(image: media.artwork, size: 92, cornerRadius: 16)
                        .shadow(color: accent.opacity(info.isPlaying ? 0.45 : 0.15), radius: artworkHovered ? 16 : 12)
                        .scaleEffect(info.isPlaying ? (artworkHovered ? 1.04 : 1) : 0.88)
                        .overlay(alignment: .bottomTrailing) {
                            AppIcon(bundleIdentifier: info.bundleIdentifier, size: 26)
                                .offset(x: 6, y: 6)
                        }
                        .motion(Motion.responsive, value: info.isPlaying)
                        .motion(Motion.press, value: artworkHovered)
                }
                .buttonStyle(PressableStyle())
                .onHover { artworkHovered = $0 }
                .help("Open \(AppIconCache.name(for: info.bundleIdentifier) ?? "the app that's playing")")

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.title.isEmpty ? "Unknown title" : info.title)
                            .font(.system(size: 14, weight: .semibold))
                        Text(info.artist.isEmpty ? info.album : info.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)

                    PlaybackScrubber(info: info, accent: accent, onSeek: media.seek(to:))

                    HStack(spacing: 26) {
                        controlButton("backward.fill", size: 15, help: "Previous", action: media.previousTrack)
                        controlButton(info.isPlaying ? "pause.fill" : "play.fill", size: 22,
                                      help: info.isPlaying ? "Pause" : "Play", action: media.togglePlayPause)
                        controlButton("forward.fill", size: 15, help: "Next", action: media.nextTrack)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            HStack(spacing: 16) {
                ArtworkView(image: nil, size: 92, cornerRadius: 16)
                VStack(alignment: .leading, spacing: 4) {
                    Text(media.isAvailable ? "Nothing playing" : "Now Playing unavailable")
                        .font(.system(size: 14, weight: .semibold))
                    Text(media.isAvailable
                         ? "Play something in Music, Spotify or a browser and it shows up here."
                         : media.unavailableReason ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }

    private func controlButton(_ symbol: String, size: CGFloat, help: String,
                               action: @escaping @MainActor () -> Void) -> some View {
        MediaControlButton(symbol: symbol, size: size, action: action)
            .help(help)
            .accessibilityLabel(help)
    }
}

/// A playback button that nudges in the direction it skips when clicked.
private struct MediaControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: @MainActor () -> Void
    @State private var clicks = 0

    var body: some View {
        Button {
            clicks += 1
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce.byLayer, value: clicks)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(NotchIconButtonStyle())
    }
}

/// Progress bar that ticks while playing and can be dragged to seek.
struct PlaybackScrubber: View {
    let info: NowPlayingInfo
    let accent: Color
    let onSeek: @MainActor (TimeInterval) -> Void

    @State private var dragFraction: Double?
    @State private var isHovered = false

    var body: some View {
        // A plain once-a-second tick: the bar moves a pixel or so a second, and
        // an animation timeline would keep the display clock running for it.
        TimelineView(.periodic(from: .now, by: info.isPlaying && dragFraction == nil ? 1 : 3600)) { context in
            let duration = info.duration ?? 0
            let elapsed = info.elapsed(at: context.date)
            let fraction = dragFraction ?? (duration > 0 ? elapsed / duration : 0)
            let shownElapsed = dragFraction.map { $0 * duration } ?? elapsed

            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.primary.opacity(0.16))
                        Capsule().fill(accent).frame(width: geometry.size.width * min(max(fraction, 0), 1))
                    }
                    .frame(height: dragFraction != nil ? 7 : isHovered ? 6 : 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withMotion(Motion.press) { isHovered = hovering }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragFraction = Self.clamp(value.location.x / geometry.size.width)
                            }
                            .onEnded { value in
                                let target = Self.clamp(value.location.x / geometry.size.width) * duration
                                dragFraction = nil
                                onSeek(target)
                            }
                    )
                }
                .frame(height: 10)
                .motion(Motion.press, value: dragFraction == nil)

                HStack {
                    Text(Format.clock(shownElapsed))
                    Spacer()
                    Text(duration > 0 ? "-" + Format.clock(max(duration - shownElapsed, 0)) : "Live")
                }
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .allowsHitTesting(duration > 0)
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

private struct QuickStats: View {
    let monitor: SystemMonitor
    let settings: AppSettings

    var body: some View {
        let snapshot = monitor.snapshot
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                StatRing(title: "CPU", fraction: snapshot.cpu.total, color: Theme.cpu)
                    .frame(maxWidth: .infinity)
                StatRing(title: "GPU", fraction: snapshot.gpu?.utilization, color: Theme.gpu)
                    .frame(maxWidth: .infinity)
                StatRing(title: "RAM", fraction: snapshot.memory.usedFraction, color: Theme.pressure(snapshot.memory.pressure))
                    .frame(maxWidth: .infinity)
                if let battery = snapshot.battery {
                    StatRing(title: "BAT", fraction: Double(battery.percent) / 100,
                             color: Theme.battery(percent: battery.percent, charging: battery.isCharging),
                             symbol: battery.isCharging ? "bolt.fill" : nil)
                        .frame(maxWidth: .infinity)
                } else {
                    StatRing(title: "DISK", fraction: snapshot.disk.usedFraction, color: Theme.disk)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 12) {
                Chip(symbol: "thermometer.medium",
                     text: snapshot.temperatures.soc.map { Format.temperature($0, unit: settings.temperatureUnit) } ?? "–",
                     color: Theme.temperature)
                Chip(symbol: "arrow.down", text: Format.rate(snapshot.network.downloadBytesPerSecond), color: Theme.download)
                Chip(symbol: "arrow.up", text: Format.rate(snapshot.network.uploadBytesPerSecond), color: Theme.upload)
            }
        }
    }
}
